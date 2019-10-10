classdef bats < handle

%--------------------------------------------------
%     PROPERTIES
  properties
    % General properties
    Global

    % BATS-R-US Ouput
    Output
  end

  properties (Dependent)
    % BATS-R-US Derived
    Derived
  end

  properties (Hidden, GetAccess = protected, SetAccess = protected)
    %------------------------------
    %   Physical Variables
    % Global
    GlobalFile = '';
    GlobalTime = '';
    GlobalUnits = struct();
    GlobalCoordinateSystem = '';

    % Bats Output
    x, y, z
    bx, by, bz
    b1x, b1y, b1z
    ux, uy, uz
    jx, jy, jz
    rho
    p
    e

    % BATS-R-US Derived quantities
    % Magnitudes
    b, b1, u, j

    % Vectors
    jxbx, jxby, jxbz, jxb
    Ex, Ey, Ez, E

    % Scalars
    Temp, Pb, Beta, Alfven
    Vth, Gyroradius, PlasmaFreq, InertialLength

    %------------------------------
    %   Internal Variables

    % Reduced domain indices
    IndicesReducedDomain
  end

%--------------------------------------------------
%     METHODS
  methods
    function obj = bats(varargin)
    % function obj = bats(varargin)
    %
    % INPUT:  If no inputs => returns empty object
    %   KWARGS:
    %         'file': string: '/path/to/cdf/file.cdf'
    %         'variables', var : with var a cell array of strings with the name of the variables to load.
    %                            If not specified, load all variables
    %                            {'x','y','z','bx','by','bz','b1x','b1y','b1z',
    %                             'ux','uy','uz','jx','jy','jz','rho','p','e'}
    % METHODS:
    %       toUniformGrid()
    %       calc_
    %
    % USE:

      if nargin == 0
        disp('No Inputs. Return empty object.')
        return
      elseif mod(nargin,2) == 1
        disp('Wrong number of inputs. Inputs go by pair, keyword + value');
        return
      end
      if find(strcmp('file',varargin))
        s = varargin{ find(strcmp('file',varargin))+1 };
      end
      if find(strcmp('variables',varargin))
        var = varargin{ find(strcmp('variables',varargin))+1 };
        var{end+1} = 'x'; var{end+1} = 'y'; var{end+1} = 'z';
        var = intersect(var,var);
      else
        % This should be handled differently.
        var = {'x','y','z','bx','by','bz','b1x','b1y','b1z','ux','uy','uz','jx','jy','jz','rho','p','e'};
      end
      % Treat varargin
      [data,info] = cdfread(s,'Variables',var,'ConvertEpochToDatenum',true,'CombineRecords',true);

      obj.GlobalFile = s;
      obj.GlobalTime = '';
      obj.GlobalCoordinateSystem = info.GlobalAttributes.grid_1_type;

      for i = 1 : numel(var)
        obj.GlobalUnits.(var{i}) = ...
                  char(info.VariableAttributes.units(strcmp(info.VariableAttributes.units(:,1),var{i}),2));
        obj.(var{i}) = data{i};
      end
    end % End of bats
    %------------------------------------------------------------

    %--------------------------------------------------
    %     Getters
    function Global = get.Global(obj)
      Global.File = obj.GlobalFile;
      Global.Time = obj.GlobalTime;
      Global.Units= obj.GlobalUnits;
      Global.CoordinateSystem = obj.GlobalCoordinateSystem;
    end
    %------------------------------------------------------------
    function Output = get.Output(obj)
      Output.x = obj.x;
      Output.y = obj.y;
      Output.z = obj.z;
      Output.bx = obj.bx;
      Output.by = obj.by;
      Output.bz = obj.bz;
      Output.b1x = obj.b1x;
      Output.b1y = obj.b1y;
      Output.b1z = obj.b1z;
      Output.ux = obj.ux;
      Output.uy = obj.uy;
      Output.uz = obj.uz;
      Output.jx = obj.jx;
      Output.jy = obj.jy;
      Output.jz = obj.jz;
      Output.rho = obj.rho;
      Output.p = obj.p;
      Output.e = obj.e;
    end
    %------------------------------------------------------------
    function Derived = get.Derived(obj)
      Derived.b = obj.b;
      Derived.b1 = obj.b1;
      Derived.u = obj.u;
      Derived.j = obj.j;
      Derived.jxbx = obj.jxbx;
      Derived.jxby = obj.jxby;
      Derived.jxbz = obj.jxbz;
      Derived.jxb = obj.jxbz;
      Derived.Ex = obj.Ex;
      Derived.Ey = obj.Ey;
      Derived.Ez = obj.Ez;
      Derived.E = obj.E;
      Derived.Temp = obj.Temp;
      Derived.Pb = obj.Pb;
      Derived.Beta = obj.Beta;
      Derived.Alfven = obj.Alfven;
      Derived.Vth = obj.Vth;
      Derived.Gyroradius = obj.Gyroradius;
      Derived.PlasmaFrequency = obj.PlasmaFreq;
      Derived.InertialLength = obj.InertialLength;
    end
    %------------------------------------------------------------

    %------------------------------------------------------------
    %   Modify the data in obj
    function obj = loadFields(obj,var)

      [data,info] = cdfread(obj.GlobalFile,'Variables',var,'ConvertEpochToDatenum',true,'CombineRecords',true);

      for i = 1 : numel(var)
        if numel(var) == 1
          field = var;
          fieldData = data;
        else
          field = var{i};
          fieldData = data{i};
        end

        obj.GlobalUnits.(field) = ...
                  char(info.VariableAttributes.units(strcmp(info.VariableAttributes.units(:,1),field),2));
        obj.(field) = fieldData;

        % Check the length of the data is the same as what we already have
        % In case we reduced the domain already
        if numel(obj.x)~=numel(obj.(field)) & numel(obj.IndicesReducedDomain)==numel(obj.x)
          obj.(field) = obj.(field)(obj.IndicesReducedDomain);
        elseif numel(obj.x)~=numel(obj.(field))
          warning('Problem with the size of the newly loaded data. We suggest you reduce the domain again.');
        end
      end
    end
    %------------------------------------------------------------
    function uniData = toBatsUni(obj,cellSize,var,varargin)
      xrange = [];
      yrange = [];
      zrange = [];

      if isempty(var)
        Fields = obj1.listNonEmptyFields;
        var = {'bx','by','bz','ux','uy','uz','jx','jy','jz','rho','p'};
        var = intersect(var,Fields);
      end

      if find(strcmp('xrange',varargin))
        xr = varargin{ find(strcmp('xrange',varargin))+1 };
        xrange = [min(xr,[],'all') : single(cellSize) : max(xr,[],'all')];
      else
        xrange = [min(obj1.x,[],'all') : single(cellSize) : max(obj1.x,[],'all')];
      end
      if find(strcmp('yrange',varargin))
        yr = varargin{ find(strcmp('yrange',varargin))+1 };
        yrange = [min(yr,[],'all') : single(cellSize) : max(yr,[],'all')];
      else
        yrange = [min(obj1.y,[],'all') : single(cellSize) : max(obj1.y,[],'all')];
      end
      if find(strcmp('zrange',varargin))
        zr = varargin{ find(strcmp('zrange',varargin))+1 };
        zrange = [min(zr,[],'all') : single(cellSize) : max(zr,[],'all')];
      else
        zrange = [min(obj1.z,[],'all') : single(cellSize) : max(obj1.z,[],'all')];
      end

      uniData = batsUni(obj,'xrange',xrange,'yrange',yrange,'zrange',zrange, ...
                        'cellsize',cellSize,'interpolate',true,'variables', var);
    end
    %------------------------------------------------------------
    function [xmesh,ymesh,zmesh] = toUniformGrid(obj,obj1,cellSize,var,varargin)
    % function [xmesh,ymesh,zmesh] = toUniformGrid(obj,cellSize,var,varargin)
    %
    %   INPUT:
    %           obj = object that will contain the uniform grid
    %           obj1 = object from which it will take the data
    %           cellSize = in R units
    %           var = cellarray of variables e.g. {'bx','by'}
    %     varargin:
    %           'xrange': giving the range of values for the interp
    %           'yrange': giving the range of values for the interp
    %           'zrange': giving the range of values for the interp
    %
    %   OUTPUT:
    %           xmesh
    %           ymesh
    %           zmesh

      % Warning
      warning('This may take a long time. Make sure you have enough memory!');

      xrange = [];
      yrange = [];
      zrange = [];

      if isempty(var)     % We only care about the original fields. The rest can be quickly recomputed
        Fields = obj1.listNonEmptyFields;
        var = {'bx','by','bz','ux','uy','uz','jx','jy','jz','rho','p'};
        var = intersect(var,Fields);
      end

      if find(strcmp('xrange',varargin))
        xr = varargin{ find(strcmp('xrange',varargin))+1 };
        xrange = [min(xr,[],'all') : single(cellSize) : max(xr,[],'all')];
      else
        xrange = [min(obj1.x,[],'all') : single(cellSize) : max(obj1.x,[],'all')];
      end
      if find(strcmp('yrange',varargin))
        yr = varargin{ find(strcmp('yrange',varargin))+1 };
        yrange = [min(yr,[],'all') : single(cellSize) : max(yr,[],'all')];
      else
        yrange = [min(obj1.y,[],'all') : single(cellSize) : max(obj1.y,[],'all')];
      end
      if find(strcmp('zrange',varargin))
        zr = varargin{ find(strcmp('zrange',varargin))+1 };
        zrange = [min(zr,[],'all') : single(cellSize) : max(zr,[],'all')];
      else
        zrange = [min(obj1.z,[],'all') : single(cellSize) : max(obj1.z,[],'all')];
      end

      % Constrain the xyz used for interpolation
      shift = 5*cellSize;
      ix = find(obj1.x >= xrange(1)-shift & obj1.x <= xrange(end)+shift);
      iy = find(obj1.y >= yrange(1)-shift & obj1.y <= yrange(end)+shift);
      iz = find(obj1.z >= zrange(1)-shift & obj1.z <= zrange(end)+shift);
      ind = intersect(ix,intersect(iy,iz));
      x = double(obj1.x(ind));
      y = double(obj1.y(ind));
      z = double(obj1.z(ind));

      [xmesh,ymesh,zmesh] = ndgrid(xrange,yrange,zrange);
      xmesh = squeeze(xmesh);
      ymesh = squeeze(ymesh);
      zmesh = squeeze(zmesh);

      % Keep same info:
      for i = 1 : numel(var)
        disp(['Reshaping variable: ',var{i}]);

        F = scatteredInterpolant(x,y,z,double(obj1.(var{i})(ind)));

        obj.(var{i}) = single(F(double(xmesh), double(ymesh), double(zmesh)));
      end
    end

    %----------------------------------------
    %   Calc functions.
    %------------------------------------------------------------
    function obj = calc_b(obj)
      if isempty(obj.bx) obj.loadFields({'bx','by','bz'}); end

      obj.b = sqrt( obj.bx.^2 + obj.by.^2 + obj.bz.^2 );
      obj.GlobalUnits.b = obj.GlobalUnits.bx;
    end
    %------------------------------------------------------------
    function obj = calc_b1(obj)
      if isempty(obj.b1x) obj.loadFields({'b1x','b1y','b1z'}); end

      obj.b1 = sqrt( obj.b1x.^2 + obj.b1y.^2 + obj.b1z.^2 );
      obj.GlobalUnits.b1 = obj.GlobalUnits.b1x;
    end
    %------------------------------------------------------------
    function obj = calc_u(obj)
      if isempty(obj.ux) obj.loadFields({'ux','uy','uz'}); end

      obj.u = sqrt( obj.ux.^2 + obj.uy.^2 + obj.uz.^2 );
      obj.GlobalUnits.u = obj.GlobalUnits.ux;
    end
    %------------------------------------------------------------
    function obj = calc_j(obj)
      if isempty(obj.jx) obj.loadFields({'jx','jy','jz'}); end

      obj.j = sqrt( obj.jx.^2 + obj.jy.^2 + obj.jz.^2 );
      obj.GlobalUnits.j = obj.GlobalUnits.jx;
    end
    %------------------------------------------------------------
    function obj = calc_jxb(obj)
    % units:  [j]: muA/m^2
    %         [b]: nT
    %         [jxb]: nN/m^3
      if (isempty(obj.jx)|isempty(obj.ux))
        obj.loadFields({'jx','jy','jz','ux','uy','uz'});
      end

      obj.jxbx = (obj.jy.*obj.bz - obj.jz.*obj.by)*1e-6;
      obj.jxby = (obj.jz.*obj.bx - obj.jx.*obj.bz)*1e-6;
      obj.jxbz = (obj.jx.*obj.by - obj.jy.*obj.bx)*1e-6;
      obj.jxb  = sqrt( obj.jxbx.^2 + obj.jxby.^2 + obj.jxbz.^2 );

      obj.GlobalUnits.jxbx = 'nN/m^3';
      obj.GlobalUnits.jxby = 'nN/m^3';
      obj.GlobalUnits.jxbz = 'nN/m^3';
      obj.GlobalUnits.jxb  = 'nN/m^3';
    end
    %------------------------------------------------------------
    function obj = calc_E(obj)
    % units:  [u]: km/s
    %         [b]: nT
    %         [E]: mV/m
      if (isempty(obj.bx)|isempty(obj.ux))
        obj.loadFields({'bx','by','bz','ux','uy','uz'});
      end

      obj.Ex = -1.0*(obj.uy.*obj.bz - obj.uz.*obj.by) / 1e3;
      obj.Ey = -1.0*(obj.uz.*obj.bx - obj.ux.*obj.bz) / 1e3;
      obj.Ez = -1.0*(obj.ux.*obj.by - obj.uy.*obj.bx) / 1e3;
      obj.E  = sqrt( obj.Ex.^2 + obj.Ey.^2 + obj.Ez.^2 );

      obj.GlobalUnits.Ex = 'mV/m';
      obj.GlobalUnits.Ey = 'mV/m';
      obj.GlobalUnits.Ez = 'mV/m';
      obj.GlobalUnits.E = 'mV/m';
    end
    %------------------------------------------------------------
    function obj = calc_temp(obj)
    % Calculated through P = nkT
    % it uses rho for n, it is fine as long as its only H+
      if (isempty(obj.p)|isempty(obj.rho))
        obj.loadFields({'p','rho'});
      end

      eV = 6241.50935;    % nPa*cm^3 to eV
      obj.Temp = eV*obj.p./obj.rho;
      obj.GlobalUnits.Temp = 'eV';
    end
    %------------------------------------------------------------
    function obj = calc_pb(obj)
    % Calculates the magnetic pressure
      if isempty(obj.b) obj.calc_b; end

      mu0 = 4*pi*1e-7;
      obj.Pb = obj.b.^2/(2*mu0)*1e-9;
      obj.GlobalUnits.Pb = 'nPa';
    end
    %------------------------------------------------------------
    function obj = calc_beta(obj)
    % Calculates beta factor
      if isempty(obj.p)   obj.loadFields('p');  end
      if isempty(obj.Pb)  obj.calc_pb;          end

      obj.Beta = obj.p./obj.Pb;
      obj.GlobalUnits.Beta = '';
    end
    %------------------------------------------------------------
    function obj = calc_alfven(obj)
    % Only works for pure protons
      if isempty(obj.b)     obj.calc_b;               end
      if isempty(obj.rho)   obj.loadFields('rho');  end

      mu0 = 4*pi*1e-7;
      m = 1.6726*1e-27;
      factor = mu0*m;
      obj.Alfven = (obj.b./sqrt(factor*obj.rho))*1e-15;
      obj.GlobalUnits.Alfven = 'km/s';
    end
    %------------------------------------------------------------
    function obj = calc_vth(obj)
    % Compute it without the temperature
    % vth = sqrt(2*p/(n*m))   with p: pressure, n: number density, m: mass
      if isempty(obj.Temp) obj.calc_temp; end

      m = 1.6276e-27;

      obj.Vth = sqrt( 2*1.6022*1e-19 * obj.Temp/m ) * 1e-3;
      obj.GlobalUnits.Vth = 'km/s';
    end
    %------------------------------------------------------------
    function obj = calc_gyroradius(obj)
      if isempty(obj.u)     obj.calc_u;     end
      if isempty(obj.Vth)   obj.calc_vth;   end

      v = sqrt(obj.u.^2 + obj.Vth.^2)*1000;
      b = obj.b*1e-9;
      m = 1.6276e-27;
      q = 1.6022e-19;
      R = 6371.2e3;

      obj.Gyroradius = m*v./(q*b*R);
      obj.GlobalUnits.Gyroradius = 'Re';
    end
    %------------------------------------------------------------
    function obj = calc_plasmafreq(obj)
      if isempty(obj.rho)   obj.loadFields('rho');  end

      m = 1.6276e-27;
      %n = (obj.rho/m)*1e6;
      n = (obj.rho)*1e6;
      q = 1.6022e-19;

      obj.PlasmaFreq = sqrt(4*pi*n*q^2/m);
      obj.GlobalUnits.PlasmaFreq = 'rad/s';
    end
    %------------------------------------------------------------
    function obj = calc_inertiallength(obj)
      if isempty(obj.Alfven)      obj.calc_alfven;      end
      if isempty(obj.PlasmaFreq)  obj.calc_plasmafreq;  end

      R = 6371.2e3;

      obj.InertialLength = obj.Alfven./(obj.PlasmaFreq*R);
      obj.GlobalUnits.InertialLength = 'Re';
    end
    %------------------------------------------------------------
    function obj = calc_all(obj)
      obj.calc_b;
      obj.calc_b1;
      obj.calc_u;
      obj.calc_j;
      obj.calc_jxb;
      obj.calc_E;
      obj.calc_temp;
      obj.calc_pb;
      obj.calc_beta;
      obj.calc_alfven;
      obj.calc_vth;
      obj.calc_gyroradius;
      obj.calc_plasmafreq;
      obj.calc_inertiallength;
    end
    %------------------------------------------------------------


    %--------------------------------------------------
    %         REDUCE DOMAIN METHODS
    function obj = reduceDomain(obj,varargin)
      if nargin == 0
        disp('No changes done. Pass arguments to reduce domain.')
        return
      end

      % Set the property to get the indices of the reduced domain
      obj.getIndexDomain(varargin{:});

      % Go through each field and only keep the desired points
      Fields = obj.listNonEmptyFields;

      for i = 1 : numel(Fields)
        obj.(Fields{i}) = obj.(Fields{i})(obj.IndicesReducedDomain);
      end
    end
    %------------------------------------------------------------

  end   % Methods

  methods (Hidden, Access = protected)
    function obj = getIndexDomain(obj,varargin)
      if find(strcmp('xrange',varargin))
        xrange = varargin{ find(strcmp('xrange',varargin))+1 };
      else
        xrange = [min(obj.x,[],'all') max(obj.x,[],'all')];
      end
      if find(strcmp('yrange',varargin))
        yrange = varargin{ find(strcmp('yrange',varargin))+1 };
      else
        yrange = [min(obj.y,[],'all') max(obj.y,[],'all')];
      end
      if find(strcmp('zrange',varargin))
        zrange = varargin{ find(strcmp('zrange',varargin))+1 };
      else
        zrange = [min(obj.z,[],'all') max(obj.z,[],'all')];
      end

      ix = find( obj.x>=min(xrange,[],'all') & obj.x<=max(xrange,[],'all') );
      iy = find( obj.y>=min(yrange,[],'all') & obj.y<=max(yrange,[],'all') );
      iz = find( obj.z>=min(zrange,[],'all') & obj.z<=max(zrange,[],'all') );
      obj.IndicesReducedDomain = intersect(ix,intersect(iy,iz));
    end
    function Fields = listNonEmptyFields(obj)
      Fields = {};
      if ~isempty(obj.x)    Fields{end+1} = 'x';      end
      if ~isempty(obj.y)    Fields{end+1} = 'y';      end
      if ~isempty(obj.z)    Fields{end+1} = 'z';      end

      if ~isempty(obj.bx)   Fields{end+1} = 'bx';     end
      if ~isempty(obj.by)   Fields{end+1} = 'by';     end
      if ~isempty(obj.bz)   Fields{end+1} = 'bz';     end

      if ~isempty(obj.b1x)  Fields{end+1} = 'b1x';    end
      if ~isempty(obj.b1y)  Fields{end+1} = 'b1y';    end
      if ~isempty(obj.b1z)  Fields{end+1} = 'b1z';    end

      if ~isempty(obj.ux)   Fields{end+1} = 'ux';     end
      if ~isempty(obj.uy)   Fields{end+1} = 'uy';     end
      if ~isempty(obj.uz)   Fields{end+1} = 'uz';     end

      if ~isempty(obj.jx)   Fields{end+1} = 'jx';     end
      if ~isempty(obj.jy)   Fields{end+1} = 'jy';     end
      if ~isempty(obj.jz)   Fields{end+1} = 'jz';     end

      if ~isempty(obj.rho)  Fields{end+1} = 'rho';    end
      if ~isempty(obj.p)    Fields{end+1} = 'p';      end
      if ~isempty(obj.e)    Fields{end+1} = 'e';      end

      if ~isempty(obj.b)    Fields{end+1} = 'b';      end
      if ~isempty(obj.b1)   Fields{end+1} = 'b1';     end
      if ~isempty(obj.u)    Fields{end+1} = 'u';      end
      if ~isempty(obj.j)    Fields{end+1} = 'j';      end

      if ~isempty(obj.jxbx) Fields{end+1} = 'jxbx';   end
      if ~isempty(obj.jxby) Fields{end+1} = 'jxby';   end
      if ~isempty(obj.jxbz) Fields{end+1} = 'jxbz';   end
      if ~isempty(obj.jxb)  Fields{end+1} = 'jxb';    end

      if ~isempty(obj.Ex)   Fields{end+1} = 'Ex';     end
      if ~isempty(obj.Ey)   Fields{end+1} = 'Ey';     end
      if ~isempty(obj.Ez)   Fields{end+1} = 'Ez';     end
      if ~isempty(obj.E)    Fields{end+1} = 'E';      end

      if ~isempty(obj.Pb)               Fields{end+1} = 'Pb';               end
      if ~isempty(obj.Vth)              Fields{end+1} = 'Vth';              end
      if ~isempty(obj.Temp)             Fields{end+1} = 'Temp';             end
      if ~isempty(obj.Beta)             Fields{end+1} = 'Beta';             end
      if ~isempty(obj.Alfven)           Fields{end+1} = 'Alfven';           end
      if ~isempty(obj.Gyroradius)       Fields{end+1} = 'Gyroradius';       end
      if ~isempty(obj.PlasmaFreq)       Fields{end+1} = 'PlasmaFreq';       end
      if ~isempty(obj.InertialLength)   Fields{end+1} = 'InertialLength';   end
    end
  end   % Methods (hidden, protected)

end     % Class