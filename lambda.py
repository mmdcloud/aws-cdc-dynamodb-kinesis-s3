import json
import boto3
import base64

output = []

def lambda_handler(event, context):
    print(event)
    for record in event['records']:
        payload = base64.b64decode(record['data']).decode('utf-8')
        print('payload:', payload)
        
        row_w_newline = payload + "\n"
        print('row_w_newline type:', type(row_w_newline))
        row_w_newline = base64.b64encode(row_w_newline.encode('utf-8'))
        
        output_record = {
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': row_w_newline
        }
        output.append(output_record)

    print('Processed {} records.'.format(len(event['records'])))
    
    return {'records': output}
