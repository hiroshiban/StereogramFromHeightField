function [checkerboard,mask]=CreatePolarCheckerBoardIDs(rmin,rmax,width,startangle,pix_per_deg,nwedges,nrings,phase)

% Creates a wedge-shaped checkerboard pattern each of whose patch has unique ID.
% function [checkerboard,mask]=CreatePolarCheckerBoardIDs(rmin,rmax,width,startangle,pix_per_deg,nwedges,nrings,phase)
%
% Generates wedge-shaped checkerboard ID pattern. Multiple start angles are acceptable
%
% [input]
% rmin        : checkerboard's minimum radius in deg, [val]
% rmax        : checkerboard's maximum radius in deg, [val]
% width       : checker width in deg, [val]
% startangle  : checker board start angle, from right horizontal meridian, clockwise
%               *** multiple start angles are acceptable ***
%               e.g. [0,12,24,36,...]
% pix_per_deg : pixels per degree, [val]
% nwedges     : number of wedges, [val]
% nrings      : number of rings, [val]
% phase       : (optional) checker's phase
%
% [output]
% checkerboard : output grayscale checkerboard, cell structure, {numel(startangle)}
%                each pixel shows each checker patch's ID or background(0)
% mask        : (optional) checkerboard regional mask, cell structure, logical
%
% Created    : "2011-04-12 11:12:37 ban"
% Last Update: "2013-11-22 18:40:38 ban (ban.hiroshi@gmail.com)"


%% check input variables
if nargin<7, help CreateEccenCheckerBoardIDs; return; end
if nargin<8, phase=0; end

%% parameter adjusting

% convert deg to pixels
rmin=rmin*pix_per_deg;
rmax=rmax*pix_per_deg;

% convert deg to radians
startangle=mod(startangle*pi/180,2*pi);
width=width*pi/180;
%if phase>width/nwedges, phase=mod(phase,width/nwedges); end
phase=phase*pi/180;

% add small lim in checkerboard image, this is to avoid unwanted juggy edges
imsize_ratio=1.01;


%% processing

% base xy distance field
[xx,yy]=meshgrid((0:1:imsize_ratio*2*rmax)-imsize_ratio*rmax,(0:1:imsize_ratio*2*rmax)-imsize_ratio*rmax);
%if mod(size(xx,1),2), xx=xx(1:end-1,:); yy=yy(1:end-1,:); end
%if mod(size(xx,2),2), xx=xx(:,1:end-1); yy=yy(:,1:end-1); end

% convert distance field to radians and degree fields
thetafield=mod(atan2(yy,xx),2*pi);

% calculate binary class (-1/1) along eccentricity for checkerboard (anuulus)
radii=linspace(rmin,rmax,nrings+1); radii(1)=[]; % annulus width
r=sqrt(xx.^2+yy.^2); % radius
cid=zeros(size(xx)); % checker id, eccentricity
for i=length(radii):-1:1
  cid(rmin<r & r<=radii(i))=i;
end

% calculate binary class (-1/1) along polar angle for checkerboard (wedge)
% and generate checkerboards
checkerboard=cell(numel(startangle),1);
mask=cell(numel(startangle),1);

for aa=1:1:numel(startangle)

  % !!!NOTICE!!!
  % We need to create each checkerboard following the procedures below
  %  1. generate radian angle field
  %  2. rotate it based on startangle & phase
  %  3. generate checkerboard IDs
  % This consumes much CPU power and time, but it is definitely important.
  %
  % To use imrotate after creating one image may look more sophisticated, but we
  % should not do that. This is because when we use imrotate (or fast_rotate)
  % or Screen('DrawTexture',....,rotangle,...), the displayed image will result
  % in low quality with juggy artefact along checker edges.

  done_flag=0;

  % just flip dimension and copy, if the currect checkerboard is one of
  % 180 deg flipped version of previously generated checkerboards.
  % this is to save calculation time
  if aa>=2
    for tt=1:1:aa-1
      %if startangle(aa)==mod(startangle(tt)+pi,2*pi)
      if abs(startangle(aa)-mod(startangle(tt)+pi,2*pi))<0.01 % this is to avoid round off error
        %fprintf('#%d checkerboard is generated by just copying/flipping from #%d checkerboard\n',aa,tt); % debug code
        checkerboard{aa}=flipdim(flipdim(checkerboard{tt},2),1);
        if nargout>=2
          mask{aa}=flipdim(flipdim(mask{tt},2),1);
        end
        done_flag=1;
        continue;
      end
    end
  end

  if ~done_flag

    % calculate inner regions
    minlim=startangle(aa);
    maxlim=mod(startangle(aa)+width,2*pi);
    if minlim==maxlim % whole annulus
      inidx=find( (rmin<=r & r<=rmax) );
    elseif minlim>maxlim
      inidx=find( (rmin<=r & r<=rmax) & ( (minlim<=thetafield & thetafield<=2*pi) | (0<=thetafield & thetafield<=maxlim) ) );
    else
      inidx=find( (rmin<=r & r<=rmax) & ( (minlim<=thetafield) & (thetafield<=maxlim) ) );
    end

    % calculate wedge IDs
    th=thetafield(inidx)-startangle(aa)+phase;
    th=mod(th,2*pi);
    cidp=zeros(size(thetafield));
    cidp(inidx)=ceil(th/width*nwedges); % checker id, polar angle

    % correct wedge IDs
    if phase~=0 %mod(phase,width/nwedges)~=0
      cidp(inidx)=mod(cidp(inidx)-(2*pi/(width/nwedges)-1),2*pi/(width/nwedges))+1;
      minval=unique(cidp); minval=minval(2); % not 1 because the first value is 0 = background;
      cidp(cidp>0)=cidp(cidp>0)-minval+1;
      true_nwedges=numel(unique(cidp))-1; % -1 is to omit 0 = background;
    else
      true_nwedges=nwedges;
    end

    % calcuate ring IDs
    cide=cid;

    % generate checker's ID
    checkerboard{aa}=zeros(size(thetafield));
    checkerboard{aa}(inidx)=cidp(inidx)+(cide(inidx)-1)*true_nwedges;

    % exclude outliers
    checkerboard{aa}(r<rmin | rmax<r)=0;

    % generate mask
    if nargout>=2
      mask{aa}=logical(checkerboard{aa});
    end

  end % if ~done_flag

end % for aa=1:1:numel(startangle)

return
