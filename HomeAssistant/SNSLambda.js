var AWS = require("aws-sdk")
, sns = new AWS.SNS();

exports.handler = function (event, context) {
    console.log("Received event", event)
    if (event.target) {
        var endpointArn = "arn:aws:sns:us-west-2:663692594824:endpoint/APNS_SANDBOX/HomeAssistant/"+event.target;
        
        console.log("Sending to endpointArn", endpointArn)
        if (event.message) {
            var alertTitle = event.message
            if (event.title) {
                alertTitle = event.title+"\n"+event.message
            }
            
            var apspayload = { alert: alertTitle }
            
            if (event.data) {
                for (var attrname in event.data) {
                    apspayload[attrname] = event.data[attrname];
                }
            }
            
            var payload = { APNS_SANDBOX: { aps: apspayload } };
            
            payload["APNS_SANDBOX"] = JSON.stringify(payload.APNS_SANDBOX);
            payload = JSON.stringify(payload);
            
            console.log("Publishing notification:", payload);
            sns.publish({
                        Message: payload,
                        MessageStructure: "json",
                        TargetArn: endpointArn
                        }, function(err, data) {
                        if (err) {
                        console.error("Error when attempting to publish", err);
                        context.fail(JSON.stringify({"message": "Error when publishing", "error": err}))
                        return;
                        } else {
                        console.log("Notification published:", data)
                        context.succeed(data)
                        }
                        });
        } else {
            context.fail("No message given")
        }
    } else {
        context.fail("No target given")
    }
};