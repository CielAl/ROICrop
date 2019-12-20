classdef BaseObject < matlab.mixin.Copyable

    properties(Constant, Access = private)
        FORMAT_MSG_WRONG_PROPERTY = [ 'Wrong property name: %s' ...
                                 'for class: %s'];
        MSG_ODD_NUM_NV_PAIR = [ 'Number of elements in a series of' ...
                            'Name-Value pair should be even'];
    end
    
    methods
        
        function obj = BaseObject(varargin)
            obj.load(varargin{:});
        end
        
        function load(obj,varargin)
             argStruct = RoiCrop.BaseObject.parseNameValue(varargin{:});
             for fields = fieldnames(argStruct)'
                 name = fields{:};
                 if isprop(obj,name)
                     obj.(name) = argStruct.(name);
                 else
                     error(RoiCrop.BaseObject.FORMAT_MSG_WRONG_PROPERTY, ...
                           name,...
                           class(obj));
                 end
             end
        end
    end
    
    
    methods(Static)
        function argStruct = parseNameValue(varargin)
           % parse name-value pairs into a struct.
            if numel(varargin)<1
                argStruct = struct();          
            elseif numel(varargin) == 1
                if isstruct(varargin{1})
                    argStruct = varargin{1};
                elseif iscell(varargin{1})
                    argStruct = ...
                        RoiCrop.BaseObject.nameValue2struct(varargin{1});
                end
            else
                argStruct = ...
                    RoiCrop.BaseObject.nameValue2struct(varargin{:});
            end
            postCond = logical(exist('argStruct', 'var'));
            assert(postCond, ['Post_Cond_Fail:' ...
                'argStruct not set in the flow']);
        end
      function args = nameValue2struct(varargin)
          % varargin = {n,v,n,v,...}
          args =  cell2struct(varargin(2:2:end),varargin(1:2:end),2);
      end
  end    
end