function map = occupancy(serPort)

if isSimulator(serPort)
    td = 0.1; % time delta to wait
    tdd = 0.4; % time delta - used to be 3.0
    fs = 0.2; % forward speed
    as = 0.2; % angle speed (0, 0.2 m/s)    
    corrective = 1.0; %.5; % how much to fix the angle deltas by
else
    td = 0.001; %was .01
    tdd = 0.01;
    fs = 0.1; %was .1
    as = 0.02; %was .02
    corrective = 1.0; 
end

timeout = 90.0;

pos = [0,0,0]; % [x,y,theta]

% map size in terms of 
mapsize = 30;
map = -1*ones(mapsize);

% drawing initialization

robit_size = 0.25; % also set it in plot_grid
figure(1) % set the active figure handle to figure 1
clf; % clear figure 1
len = length(map); % assume the map is square
mapsize = len*robit_size * 1.1;
axis([-mapsize/2 mapsize/2  -mapsize/2 mapsize/2]); % in meters
hold on; % don't clear figure with each plot()

% draw a gray background
map_size = robit_size*len;
rectangle('position', [-map_size/2,-map_size/2, map_size, map_size],...
          'edgecolor',[0.5,0.5,0.5],...
          'facecolor',[0.5,0.5,0.5]);

last_updated = tic;

while(toc(last_updated) < timeout)
        DistanceSensorRoomba(serPort); % clear distance
    br = NaN; bl = NaN; bf = NaN;
    while(isnan(br) || isnan(bl) || isnan(bf))
        [br,bl, wr,wl,wc, bf] = BumpsWheelDropsSensorsRoomba(serPort);
    end
    if (wr == 1 || wl == 1 || wc == 1)
        return;
    end
    bump = (bf==1 || br==1 || bl==1);
    
    SetFwdVelRadiusRoomba(serPort, fs, inf);
    %KEEP MOVING AROUND RANDOMLY, HOPE SHIT DON'T BREAK.
    while(bump == 0 && toc(last_updated) < timeout)
        pause(tdd);
        SetFwdVelRadiusRoomba(serPort,0,0);
        % turn until we are pointing towards the goal
        da = 1.0;
        start_angle = pos(3);%AngleSensorRoomba(serPort);
        while(abs(start_angle-pos(3)) < pi/8 && ...
                toc(last_updated) < timeout)
            turnAngle(serPort, as, pi/8*da);
            da = 0.9*da;
            angle = AngleSensorRoomba(serPort);
            pos(3) = pos(3) + corrective*angle;
        end
        SetFwdVelRadiusRoomba(serPort,fs,inf);
        
        % go for a little while
        pause(td);
        % poll the bumpers

        br = NaN; bl = NaN; bf = NaN;
        while(isnan(br) || isnan(bl) || isnan(bf))
            [br,bl, wr,wl,wc, bf] = BumpsWheelDropsSensorsRoomba(serPort);
        end
        bump = (br == 1 || bl == 1 || bf == 1);
        % if picked up, kill
        if (wr == 1 || wl == 1 || wc == 1)
            SetFwdVelRadiusRoomba(serPort, 0, 0);
            return;
        end
        % update the location
        d = DistanceSensorRoomba(serPort);
        pos(1) = pos(1) + d*cos(pos(3));
        pos(2) = pos(2) + d*sin(pos(3));
        % draw current location
        map = plot_grid(map, pos, bf, br, bl, last_updated);
        last_updated = map{2};
        change = map{3};
        map = map{1};
        % check if we hit a known obstacle
        if(change == 0 && bump == 1)
            % if so, turn tail and run for a bit
            turnAngle(serPort, as, 180);
            angle = AngleSensorRoomba(serPort);
            pos(3) = pos(3) + corrective*angle;
            
            dtraveled = 0.0;
            while(dtraveled < 1.0)
                SetFwdVelRadiusRoomba(serPort,fs,inf);
                pause(td);
                SetFwdVelRadiusRoomba(serPort,0,inf);
                
                d = DistanceSensorRoomba(serPort);
                dtraveled = dtraveled + d;
                pos(1) = pos(1) + d*cos(pos(3));
                pos(2) = pos(2) + d*sin(pos(3));
                
                br = NaN; bl = NaN; bf = NaN;
                while(isnan(br) || isnan(bl) || isnan(bf))
                    [br,bl, wr,wl,wc, bf] = BumpsWheelDropsSensorsRoomba(serPort);
                end
                bump = (bf==1 || br==1 || bl==1);
                if (wr == 1 || wl == 1 || wc == 1)
                    return;
                end
                % breakout chain
                if(toc(last_updated) > timeout || bump == 1)
                    break;
                end
            end
            % breakout chain
            if(toc(last_updated) > timeout || bump == 1)
                break;
            end
        end
    end
    
    if(toc(last_updated) > timeout)
        break;
    end
        
    SetFwdVelRadiusRoomba(serPort, 0, inf);

    % wall follow
    a = wall_follower(serPort, map, pos, last_updated);
    % check if we've picked it up in the wall following process
    br = NaN; bl = NaN; bf = NaN;
    while(isnan(br) || isnan(bl) || isnan(bf))
        [br,bl, wr,wl,wc, bf] = BumpsWheelDropsSensorsRoomba(serPort);
    end
    if (wr == 1 || wl == 1 || wc == 1)
        return;
    end
    % update the map
    pos = a{1};
    map = a{2};
    last_updated = a{3};
    
    map = plot_grid(map, pos, bf, br, bl, last_updated);
    last_updated = map{2};
    map = map{1};

    turnAngle(serPort,as,135); % fucking shit uses degrees
    pos(3) = pos(3) + corrective*AngleSensorRoomba(serPort);
    
end

SetFwdVelRadiusRoomba(serPort,0,inf);
disp('Done!')

end

