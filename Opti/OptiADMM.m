classdef OptiADMM < Opti
    %% OptiADMM : Alternating Direction Method of Multipliers algorithm
    %  Matlab Inverse Problems Library
    %
    % -- Description
    % Implements the ADMM algorithm [1] to minimize:
    %    $$ F_0(H_0*x) + \sum_{n=1}^N F_n(y_n) $$
    % subject to:
    %    $$ H_n*x=y_n \forall n \in {1,...,N}$$
    % where the H_n are linear operators and F_n are functional with an implementation of the
    % proximity operator for n = 1,...,N (and not necessarily for n=0)
    %
    % In fact the algorithm aims to minimize the Lagrangian formulation of the above problem:
    % $$ L(x,y_1...y_n,w_1...w_) = F_0(H_0*x) + \sum_{n=1}^N 0.5*\rho_n*||H_n*x - y_n + w_n/rho_n||^2 + F_n(y_n)$$
    % where the \rho_n >0 n=1...N are the multipliers.
    %
    % -- Example
    %   ADMM= OptiADMM(F0,H0,Fn,Hn,rho_n,solver,OutOp)
    % where F0 is a FUNC object, H0 a LINOP object, Fn a cell of N FUNC, Hn a cell of N LINOP, 
    % rho_n a vector of N nonnegative scalars and solver a function handle such that:
    %   solver(z_n,rho_n)
    % where z_n is a cell of N elements and rho_n as above, minimizes the following function:
    %    $$ F_0(H_0*x) + \sum_{n=1}^N 0.5*\rho_n||H_n*x -z_n||^2 $$
    % Finally OutOp is a OutputOpti object.
    %
    % Note: If F0=[], then solver is not mandatory and by default the ADMM algorithm will
    %       use the Conjugate Gradient algorithm (see OptiConjGrad) to make the minimization task
    %       of solver. However, if one has a faster method than applying a conjugate gradient to 
    %       perform this step, it is recommended to provide a solver.
    %       If F0 is nonempty, then solver is MANDATORY. 
    %
    % -- Properties
    % * |maxiterCG|   number of iteration for Conjugate Gradient (when used)
    % * |rho_n|       vector containing the multipliers
    % * |OutOpCG|     OutputOpti object for Conjugate Gradient (when used)
    % * |ItUpOutCG|   ItUpOut parameter for Conjugate Gracdient (when used, default 0)
    %
    % -- References
	% [1] Boyd, Stephen, et al. "Distributed optimization and statistical learning via the alternating direction 
	%     method of multipliers." Foundations and Trends in Machine Learning, 2011.
    %
    % Please refer to the OPTI superclass for general documentation about optimization class
    % See also Opti, OptiConjGrad, LinOp, Func, OutputOpti
    %
    %     Copyright (C) 2017 E. Soubies emmanuel.soubies@epfl.ch
    %
    %     This program is free software: you can redistribute it and/or modify
    %     it under the terms of the GNU General Public License as published by
    %     the Free Software Foundation, either version 3 of the License, or
    %     (at your option) any later version.
    %
    %     This program is distributed in the hope that it will be useful,
    %     but WITHOUT ANY WARRANTY; without even the implied warranty of
    %     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %     GNU General Public License for more details.
    %
    %     You should have received a copy of the GNU General Public License
    %     along with this program.  If not, see <http://www.gnu.org/licenses/>.

    % Protected Set and public Read properties     
    properties (SetAccess = protected,GetAccess = public)
		F0=[];               % func F0
		Fn;                  % Cell containing the Func Fn
		H0=LinOpIdentity();  % LinOp H0
		Hn;                  % Cell containing the LinOp Hn
		solver=[];           % solver for the last step of the algorithm
    end
    % Full protected properties 
    properties (SetAccess = protected,GetAccess = protected)
		yn;    % Internal parameters
		zn;
		wn;
		Hnx;
		A;     % LinOp for conjugate gradient (if used)
    end
    % Full public properties
    properties
		rho_n;                 % vector containing the multipliers
		maxiterCG=20;          % max number of Conjugate Gradient iterates (when used)
		OutOpCG=OutputOpti();  % OutputOpti object for Conjugate Gradient (when used)
		ItUpOutCG=0;           % ItUpOut parameter for Conjugate Gradient (when used)
    end
    
    methods
    	%% Constructor
    	function this=OptiADMM(F0,H0,Fn,Hn,rho_n,solver,OutOp)
    		this.name='Opti ADMM';
    		if ~isempty(F0), this.F0=F0; end
    		if ~isempty(H0), this.H0=H0; end
    		if nargin<=5, solver=[]; end
    		if nargin==7 && ~isempty(OutOp),this.OutOp=OutOp;end   		
    		assert(length(Fn)==length(Hn),'Fn, Hn and rho_n must have the same length');
    		assert(length(Hn)==length(rho_n),'Fn, Hn and rho_n must have the same length');
    		this.Fn=Fn;
    		this.Hn=Hn;
    		this.rho_n=rho_n;
    		if ~isempty(F0) % todo: can include quadratic F0 in this case as well.
    			assert(~isempty(solver),'when F0 is nonempty a solver must be given (see help)');
    			this.cost=F0.o(H0) + Fn{1}.o(Hn{1});
    		else
    			this.cost=Fn{1}.o(Hn{1});
    		end
    		this.solver=solver;  		
    		for n=2:length(Fn)
    			this.cost=this.cost+Fn{n}.o(Hn{n});
			end
			if isempty(this.solver)
				this.A=SumLinOp({this.Hn{1}'*this.Hn{1}},[this.rho_n(1)]);
				for n=2:length(this.Hn)
					this.A=SumLinOp({this.A,this.Hn{n}'*this.Hn{n}},[1,this.rho_n(n)]);
				end
			end
    	end 
    	%% Run the algorithm
        function run(this,x0) 
			if ~isempty(x0), % To restart from current state if wanted
				this.xopt=x0;
				for n=1:length(this.Hn)
					this.yn{n}=this.Hn{n}.Apply(this.xopt);
					this.Hnx{n}=this.yn{n};
					this.wn{n}=zeros(size(this.yn{n}));
				end
			end;  
			assert(~isempty(this.xopt),'Missing starting point x0');
			tstart=tic;
			this.OutOp.init();
			this.niter=1;
			this.starting_verb();
			while (this.niter<this.maxiter)
				this.niter=this.niter+1;
				xold=this.xopt;
				% - Algorithm iteration
				for n=1:length(this.Fn)
					this.yn{n}=this.Fn{n}.prox(this.Hnx{n} + this.wn{n}/this.rho_n(n),1/this.rho_n(n));
					this.zn{n}=this.yn{n}-this.wn{n}/this.rho_n(n);
				end
				if isempty(this.solver)
					b=this.rho_n(1)*this.Hn{1}.Adjoint(this.zn{1});
					for n=2:length(this.Hn)
						b=b+this.rho_n(n)*this.Hn{n}.Adjoint(this.zn{n});
					end
					CG=OptiConjGrad(this.A,b,[],this.OutOpCG);
					CG.maxiter=this.maxiterCG;
					CG.ItUpOut=this.ItUpOutCG;
					CG.run(this.xopt);
					this.xopt=CG.xopt;
				else
					this.xopt=this.solver(this.zn,this.rho_n, this.xopt);
				end
				for n=1:length(this.wn)
					this.Hnx{n}=this.Hn{n}.Apply(this.xopt);
					this.wn{n}=this.wn{n} + this.rho_n(n)*(this.Hnx{n}-this.yn{n});
				end
				% - Convergence test
				if this.test_convergence(xold), break; end
				% - Call OutputOpti object
				if (mod(this.niter,this.ItUpOut)==0),this.OutOp.update(this);end
			end 
			this.time=toc(tstart);
			this.ending_verb();
        end
	end
end
