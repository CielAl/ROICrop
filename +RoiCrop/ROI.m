classdef ROI < RoiCrop.BaseObject
    % ROI Summary of this class goes here
    %   Detailed explanation goes here
    properties (Constant, Access = private)
        CLASSNAME_HANDLE = 'handle';
        CLASSNAME_AX = 'matlab.graphics.axis.Axes';
        CLASSNAME_IMAGE = 'matlab.graphics.primitive.Image';
        CLASSNAME_RECT = 'images.roi.Rectangle';
        MSG_REDUCTION_SUPPORT = ['Reduction Only Support' ...
                                'with Str impath input'];
    end
    
    properties(Access = private)
        ax
        imageObj
        rects cell = {}
        cache cell = {}
        delimiter char = '_'
    end
    
    
    properties(Access= public)
        img
        basename char = 'img'
        outFormat char = 'png';
        targetFolder char = '.';
    end
    
    methods(Access = private)
        function validateFields(obj)
            % validate field types and sanity
            assert(isnumeric(obj.img))
            assert(isempty(obj.ax) || ...
                isa(obj.ax, RoiCrop.ROI.CLASSNAME_AX))
            
            assert(isempty(obj.imageObj) || ...
                isa(obj.imageObj, RoiCrop.ROI.CLASSNAME_IMAGE))            
        end
    end
    
    methods(Access = public)
        % Constructor
        function obj = ROI(varargin)
            % img: the img to annotate
            obj.load(varargin{:});
            obj.validateFields();
        end
    end
    
    
    methods(Access = public)
        % life-cycle related and GUIs
        function [out] = isAlive(obj)
            % Determine whether the ax/fig objects are still valid.
            
            % determine if ax and imageObj are handles
            typeHandle = isa(obj.ax, RoiCrop.ROI.CLASSNAME_HANDLE) && ...
                isa(obj.imageObj, RoiCrop.ROI.CLASSNAME_IMAGE);
            % short-circut:  be a handle first before calling isvalid
            out = typeHandle && isvalid(obj.ax) && isvalid(obj.imageObj);
        end
        
        function resetFigure(obj)
            % recreate the axes and the image object (GUI)
            obj.ax = axes();
            obj.ax.DataAspectRatioMode = 'manual';
            obj.imageObj = image(obj.ax, obj.img);
        end
        
        function revive(obj)
           % recreate if Fig windows are closed 
           if ~ obj.isAlive()
                obj.resetFigure()
           end
        end
        
        function focus(obj)
            % ensure the fig of the image is selected
            obj.revive()
            assert(isa(obj.ax, RoiCrop.ROI.CLASSNAME_HANDLE))
            figure(obj.ax.Parent.Number)
        end
    end
    
    
    methods(Static)
       % helpers
       function [params] = apiParams(varargin)
            ip = inputParser();
            % scales for multi-scale processing in micrometers:
            ip.addParameter('reduction', 0, @(x)isnumeric(x) && ...
                                             isscalar(x) && all(x >= 0));
            ip.addParameter('cacheFlag', false, @islogical);
            ip.parse(varargin{:});
            params = ip.Results;
       end
       function boxUpdate(src, evt)
           disp(['ROI moving previous position: ' mat2str(evt.PreviousPosition)]);
           newPos = evt.CurrentPosition;
           xmin = ceil(newPos(1));
           ymin = ceil(newPos(2));
           width  = ceil(newPos(3));
           height = ceil(newPos(4));
           
           label = sprintf('ROI_(%d, %d). Width: %d, height %d', ...
                            xmin, ymin, width, height);
           src.Label = label;
           
       end
       function output = trimRectCell(rectCell)
           % Helper of trim
           funcRect = @(x)(isa(x, RoiCrop.ROI.CLASSNAME_RECT));
           rectCell = rectCell(cellfun(funcRect, rectCell));
           output = rectCell(cellfun(@isvalid, rectCell));
       end
       
       function [output] = resizeBbox(bbox, scaling)
           % Resize the bounding box, if the current one
           % is created under a different scale while the img
           % to crop/extract has different magnifications
           % bbox: [xmin, ymin, width, height]
           % scaling: up-scale factor applied to the bbox. Scalar.
           % assume
           assert(isscalar(scaling)) 
           output = scaling .* bbox;
       end
          
       function [rows, cols] = bbox2rc(bbox)
           rows=[bbox(2), bbox(2) + bbox(4)];
           cols=[bbox(1), bbox(1) + bbox(3)];
       end

       function [rows, cols] = validateBbox(bbox, widthImg, heightImg)
           clip = @(x, low, high) min(max(x, low), high);
           [rows, cols] = RoiCrop.ROI.bbox2rc(bbox);
           [ymin, ymax] = deal(rows(1), rows(2));
           [xmin, xmax] = deal(cols(1), cols(2));
           
           xmin = clip(xmin, 1, widthImg);
           ymin = clip(ymin, 1, heightImg);
           
           xmax = clip(xmax, xmin + 1, widthImg);
           ymax = clip(ymax, ymin + 1, heightImg);
           rows = [ymin, ymax];
           cols = [xmin, xmax];
       end
       
       function [heightRaw, widthRaw] = imgSize(imgIn)
            if ischar(imgIn)   
                imgInfo = imfinfo(imgIn); 
                [heightRaw, widthRaw] = deal(imgInfo.Height, ...
                                             imgInfo.Width);
            else
                [heightRaw, widthRaw, ~] = size(imgIn);
            end           
       end
       
       function [view, bboxResized] = cropWSI(imgIn, bbox, reduction)
            % Crop the imgIn using bbox.
            % imgIn: str. The format must support 'PixelRegion', e.g JP2000
            %

            if nargin < 3
                reduction = 0;
            else
                assert(isnumeric(reduction) && reduction >= 0)
                assert(reduction == 0 | ischar(imgIn), ...
                    RoiCrop.ROI.MSG_REDUCTION_SUPPORT);
            end
            scaling = pow2(reduction);
              
            [heightRaw, widthRaw] = RoiCrop.ROI.imgSize(imgIn);
            height = heightRaw * scaling;
            width = widthRaw * scaling;
            
            bboxResized = RoiCrop.ROI.resizeBbox(bbox, scaling);
            [rows, cols] = RoiCrop.ROI.validateBbox(bboxResized, ...
                                                      width, ...
                                                      height);
            view = RoiCrop.ROI.cropHelper(imgIn, rows, cols, reduction); 
       end
       
       function view = arrayViewWithTrailingDim(img, rows, cols)
           numDim = ndims(img);
           assert(numDim >= 2);
           trailingSize = numDim - 2;
           trail = repmat({':'}, 1, trailingSize);
           rows = ceil(rows);
           cols = ceil(cols);
           view = img(rows(1): rows(2), ...
                      cols(1): cols(2), ...
                      trail{:});
       end
       
       function [view] = cropHelper(imgIn, rows, cols, reduction)
            if ischar(imgIn)
                args = {'ReductionLevel', reduction, ...
                    'PixelRegion', {rows, cols}};
                view = imread(imgIn, args{:});
                return
            end
            assert(reduction == 0, ['reduction of arr input' ...
                                        'temporally unsupported']);
            view = RoiCrop.ROI.arrayViewWithTrailingDim(imgIn, ...
                                                          rows, ...
                                                          cols);                                                                      
       end
       
    end
    
    methods(Access = public)
       % drawing    
       function trim(obj)
           % Select only valid handles in the rectCell.
           % In case that some handles become invalid due to deletion.
           obj.rects = RoiCrop.ROI.trimRectCell(obj.getRects(false));
       end
       
       function draw(obj, limit, reset)
           % Draw rect ROIs and store the location into obj.rects
           % limit (int): number of ROIs to draw
           if reset
               obj.clearRects();
               obj.resetFigure();
           end
           for ii = 1: limit
               obj.focus();
               pause();
               label = sprintf('ROI_%d', ii);
               rect = drawrectangle(obj.ax, ...
                                    'Label', label, ...
                                    'Color',[1 0 0]);
               addlistener(rect,'MovingROI',@RoiCrop.ROI.boxUpdate);
               addlistener(rect,'ROIMoved',@RoiCrop.ROI.boxUpdate);                 
               obj.addRect(rect)
               % continue by enter
               
           end
           % trim the cell array in case some rectangles are deleted
           obj.trim();
       end
       function [fname] = outputName(obj, actualBbox, delimiter)
           % actualBbox - raw. Do not convert.
           boxStrCell = arrayfun(@num2str, ...
                                 actualBbox, 'UniformOutput', false);
           position_tag = join(boxStrCell, '_');
           fnameGrp = [{obj.basename}, position_tag(:)'];
           fname = [join(fnameGrp, delimiter), '.', obj.outFormat];
           fname = join(fname, ''); 
           fname = fullfile(obj.targetFolder, fname{1});
       end
       
       function writeImgFile(obj, view, actualBbox)
           fname = obj.outputName(actualBbox, obj.delimiter);
           imwrite(view, fname, obj.outFormat);
       end
       function [imgCache] = saveROIByImageHelper(obj, ...
                                                  imgIn, ...
                                                  reduction, ...
                                                  cacheFlag)
           numROIs = numel(obj.getRects());
           imgCache = cell(1, numROIs);
           for ii = 1: numROIs
               rectROI = obj.getRects{ii};
               bbox = rectROI.Position;
               [view, bboxResized] = RoiCrop.ROI.cropWSI(imgIn, ...
                                                         bbox, ...
                                                         reduction);
               
               obj.writeImgFile(view, bboxResized)
               if cacheFlag
                   imgCache{ii} = view;
               end
           end
       end
       
       function [varargout] = saveROIByImage(obj, imgIn, varargin)
    
           params = RoiCrop.ROI.apiParams(varargin{:});      
           obj.trim();
           imgCache = obj.saveROIByImageHelper(imgIn, ...
                                               params.reduction, ...
                                               params.cacheFlag);
           if params.cacheFlag
               varargout{1} = imgCache;
           end
       end
       
       function saveROI(obj)
           obj.saveROIByImage(obj.img, 'reduction', 0, 'cacheFlag', false);
       end
       
    end
    
    
    methods(Access = public)
        % fields
        function [out] = getRects(obj, trimFlag)
            if nargin < 2
                trimFlag = true;
            end
            if trimFlag
                obj.trim();
            end
            out = obj.rects;
        end
        
        function clearRects(obj)
            obj.rects = {};
        end
        function addRect(obj, rect)
            % add a rect to obj.rects
            % precondition: rect is a Rectangle and rect is 
            % not currently present in obj.rects
            memberFunc = @(x)(eq(rect, x));
            assert(isa(rect, RoiCrop.ROI.CLASSNAME_RECT))
            isDuplicateArr = cellfun(memberFunc, ...
                                     obj.rects, ...
                                     'UniformOutput', 1);
            isDuplicate = any(isDuplicateArr);
            if  ~isDuplicate
                obj.rects{end + 1} = rect;
            end
        end
        
    end
    
    
    methods(Access = public)
        % overloading
        %function out = subsref(obj, subs)
        %    rectCells = obj.getRects();
        %    out = subsasgn(rectCells, subs, []);
        %end
         function delete(obj)
             for ii = 1: numel(obj.getRects)
                 rectCell = obj.getRects(false);
                 delete(rectCell)
             end
             delete(obj.imageObj)
             delete(obj.ax)
         end
    end
end

