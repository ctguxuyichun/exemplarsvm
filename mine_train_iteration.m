function [m,mining_queue] = ...
    mine_train_iteration(m, mining_queue, training_function)
%% Mine negatives until cache is full and update the current
%% classifier using training_function (do_svm, do_rank, ...)
%%
%% Tomasz Malisiewicz (tomasz@cmu.edu)

%during first few iterations, we take many windows per image
% if iteration <= mining_params.early_late_cutoff
%   mining_params.detection_threshold = mining_params.early_detection_threshold;
% else
%   %in later iterations when we pass through many images, we use SVM cutoff
%   mining_params.detection_threshold = mining_params.late_detection_threshold;
% end

% Start wtrace with first round classifier, if not present already
if ~isfield(m.model,'wtrace')
  m.model.wtrace{1} = m.model.w;
  m.model.btrace{1} = m.model.b;
end

if m.mining_params.skip_mine == 0
  [hn, mining_queue, mining_stats] = ...
      load_hn_fg({m}, mining_queue, m.train_set, m.mining_params);
  
  m = add_new_detections(m, cat(2,hn.xs{1}{:}), cat(1,hn.bbs{1}{:}));
else
  mining_stats.num_visited = 0;
  fprintf(1,'WARNING: not mining, just updating model\n');  
end

   
m = update_the_model(m, mining_stats, training_function);

dump_figures(m);

function [m] = update_the_model(m, mining_stats, training_function)

%% UPDATE the current SVM and show the results
m.iteration = m.iteration + 1;
if ~isfield(m,'mining_stats')
  m.mining_stats{1} = mining_stats;
else
  m.mining_stats{end+1} = mining_stats;
end

m = training_function(m);
%m = do_svm(m);
%m = do_rank(m);

wex = m.model.w(:);
b = m.model.b;
r = m.model.w(:)'*m.model.svxs - m.model.b;
m.model.svbbs(:,end) = r;

if strmatch(m.models_name,'dalal')
  %% here we take the best exemplars
  allscores = wex'*m.model.x - b;
  [aa,bb] = sort(allscores,'descend');
  [aabad,bbbad] = sort(r,'descend');
  maxbad = aabad(ceil(.05*length(aabad)));
  LEN = max(sum(aa>=maxbad), m.model.keepx);
  m.model.x = m.model.x(:,bb(1:LEN));
  fprintf(1,'dalal:WE NOW HAVE %d exemplars in category\n',LEN);
end

svs = find(r >= -1.0000);

%KEEP 3#SV vectors (but at most max_negatives of them)
total_length = ceil(m.mining_params.beyond_nsv_multiplier*length(svs));
total_length = min(total_length,m.mining_params.max_negatives);

[alpha,beta] = sort(r,'descend');
svs = beta(1:min(length(beta),total_length));
m.model.svxs = m.model.svxs(:,svs);
m.model.svbbs = m.model.svbbs(svs,:);

% Append new w to trace

m.model.wtrace{end+1} = m.model.w;
m.model.btrace{end+1} = m.model.b;


function dump_figures(m)

% figure(1)
% clf
% show_cool_os(m)

% if (mining_params.dump_images == 1) || ...
%       (mining_params.dump_last_image == 1 && ...
%        m.iteration == mining_params.MAXITER)
%   set(gcf,'PaperPosition',[0 0 10 3]);
%   print(gcf,sprintf('%s/%s.%d_iter=%05d.png', ...
%                     mining_params.final_directory,m.curid,...
%                     m.objectid,m.iteration),'-dpng'); 
% end

figure(2)
clf
Isv1 = get_sv_stack(m,7);
imagesc(Isv1)
axis image
axis off
title('Exemplar Weights + Sorted Matches')
drawnow

if (m.mining_params.dump_images == 1) || ...
      (m.mining_params.dump_last_image == 1 && ...
       m.iteration == m.mining_params.MAXITER)

  imwrite(Isv1,sprintf('%s/%s.%d_iter_I=%05d.png', ...
                    m.mining_params.final_directory, m.curid,...
                    m.objectid, m.iteration), 'png');
end
