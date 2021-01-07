trigger WorkOrderClaimsTrigger on WorkOrder (after update) {
    WorkOrderClaimsHandlerV2.afterUpdate(Trigger.newMap,Trigger.oldMap);
    //WorkOrderClaimsTriggerHandler.afterUpdate(Trigger.newMap,Trigger.oldMap);
}