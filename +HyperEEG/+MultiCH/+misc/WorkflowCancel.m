function requested = WorkflowCancel(action)
%WORKFLOWCANCEL 管理统一工作流的协作式取消状态。
%   reset清除状态，request请求取消，isrequested查询，throw在已请求时
%   抛出标识为HyperEEG:UserCancelled的异常。

    stateKey = 'HyperEEGWorkflowCancelRequested';
    action = lower(string(action));

    switch action
        case "reset"
            setappdata(groot, stateKey, false);
            requested = false;
        case "request"
            setappdata(groot, stateKey, true);
            requested = true;
        case "isrequested"
            requested = isappdata(groot, stateKey) && ...
                logical(getappdata(groot, stateKey));
        case "throw"
            requested = HyperEEG.MultiCH.misc.WorkflowCancel( ...
                "isrequested");

            if requested
                fprintf('[%s] 收到工作流取消请求，当前Pipeline安全停止。\n', ...
                    char(datetime('now', ...
                    'Format', 'yyyy-MM-dd HH:mm:ss')));
                error("HyperEEG:UserCancelled", "用户已取消当前工作流。");
            end
        otherwise
            error("未知WorkflowCancel操作：%s", action);
    end

end
