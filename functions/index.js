// Load the AWS SDK for Node.js
const AWS = require('aws-sdk');

exports.handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  // Create publish parameters
  const snsParams = {
    Message: 'Hi there!',
    TopicArn: process.env.SNS_TOPIC_ARN
  };

  const DynamoDB = new AWS.DynamoDB.DocumentClient();
  const SNS = new AWS.SNS({ apiVersion: '2010-03-31' });

  let snsResponse;
  let responseBody;
  let dynamoResponse;
  switch (event.httpMethod) {
    case 'POST':
      console.log('post called');
      try {
        snsResponse = await SNS.publish(snsParams).promise();
        const dynamoParams = {
          TableName: process.env.USER_UPDATES_TABLE,
          Item: {
            "recipientNumber": process.env.RECIPIENT_NUMBER,
            "messageId": snsResponse.MessageId,
            "message": snsParams.Message,
            "requestId": snsResponse.ResponseMetadata.RequestId
          }
        };
        dynamoResponse = await DynamoDB.put(dynamoParams).promise();
        responseBody = {
          success: true
        };
        console.log(snsResponse);
        console.log(dynamoResponse);
      } catch (error) {
        responseBody = {
          success: false,
          error
        };
        console.error(error);
      }
      break;
    case 'GET':
      console.log('get called');
      try {
        const dynamoParams = {
          TableName : process.env.USER_UPDATES_TABLE,
          KeyConditionExpression: "#recipient = :number",
          ExpressionAttributeNames:{
              "#recipient": "recipientNumber"
          },
          ExpressionAttributeValues: {
              ":number":process.env.RECIPIENT_NUMBER
          }
      };
        dynamoResponse = await DynamoDB.query(dynamoParams).promise();
        responseBody = {
          success: true,
          messages: dynamoResponse
        };
        console.log(dynamoResponse);
      } catch (error) {
        responseBody = {
          success: false,
          error
        };
        console.error(error);
      }
      break;
    default:
      done(new Error(`Unsupported method "${event.httpMethod}"`));
  }

  // The output from a Lambda proxy integration must be 
  // in the following JSON object. The 'headers' property 
  // is for custom response headers in addition to standard 
  // ones. The 'body' property  must be a JSON string. For 
  // base64-encoded payload, you must also set the 'isBase64Encoded'
  // property to 'true'.
  const response = {
    statusCode: 200,
    headers: {
      "x-custom-header": "message-delivery"
    },
    body: JSON.stringify(responseBody)
  };
  console.log("response: " + JSON.stringify(response))
  return response;
};
