({
    doInit: function (component, event, helper) {
        component.set("v.showSpinner",true);
        setTimeout(function(){
            const payload = {
                isRequest: true
            };
            component.find("rqstchannel").publish(payload);
        }, 500);
    },
    
    handleReceiveMessage : function( component, event, helper) {
        if (event != null) {
            const isRequest = event.getParam("isRequest");
            if(!isRequest){
                const sessionId = event.getParam("sessionId");
                component.set("v.sessionId",sessionId);
                var action = component.get("c.createServiceBillingReport");
                action.setParams({ 
                    recordId : component.get('v.recordId'),
                    sessionId : sessionId
                });
                action.setCallback(this, function(response){
                    var state = response.getState();
                    if (state === "SUCCESS") {
                        var response = response.getReturnValue();
                        console.log('fileId'+JSON.stringify(response));
                        if(response.isSuccess){
                            component.set("v.fileId",response.fileId);
                    		component.set("v.serviceBillingId",response.serviceBillingId);
                            component.set("v.showSpinner",false);
                        }
                    }
                    else if (state === "ERROR") {
                        var errors = response.getError();
                        var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            "type": "error",
                            "title": "Error!",
                            "message": "Please check the logs for more information."
                        });
                        toastEvent.fire();
                        console.log('Error->'+JSON.stringify(error));
                    }
                });
                $A.enqueueAction(action);
            } else {
                var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            "type": "error",
                            "title": "Error!",
                            "message": "Please check the logs for more information."
                        });
                        toastEvent.fire();
                console.log('Lightning Messages are not fired');
            }
        }
    },
    
    handleCancel: function (component, event, helper) {
        console.log('here');
        var action = component.get("c.deleteBillings");
        action.setParams({ 
            cdId : component.get('v.fileId'),
            sbId : component.get('v.serviceBillingId')
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                var response = response.getReturnValue();
                if(response.isSuccess){
                    $A.get('e.force:refreshView').fire();
                }
            }
            else{
                var errors = response.getError();
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "type": "error",
                    "title": "Error!",
        			"message": "Please check the logs for more information."
                });
                toastEvent.fire();
                console.log('Error->'+JSON.stringify(error));
            }
        });
        $A.enqueueAction(action);
        $A.get("e.force:closeQuickAction").fire();
    },
    
    handleCreate: function (component, event, helper) {
        $A.get('e.force:refreshView').fire();
        $A.get("e.force:closeQuickAction").fire();
    },
})