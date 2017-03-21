function out = Expand(Mask,varargin)
    %% Selector : Selector operator
    %  Matlab Linear Operator Library
    %
    % Example:
    % Obj = Expand(Mask)
    %
    % adjoint of selector. Expands the input by adding zeros where the Mask
    % is 1.
    %
    % Please refer to the LinOp superclass for documentation
    % See also LinOp
    
    %     Copyright (C) 2015 F. Soulez ferreol.soulez@epfl.ch
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
    
    p = inputParser;
    addOptional(p,'KeepDimensions',false);
    parse(p,varargin{:});

    out = adjoint(Selector(Mask,'KeepDimensions',p.Results.KeepDimensions));
    
end
