from datetime import datetime
import os
import json
import boto3
import uuid
import logging

logger = logging.getLogger()
logging_level = os.environ['SP_LOGGING_LEVEL']
if logging_level == 'WARN':
    logger.setLevel(logging.WARN)
elif logging_level == 'INFO':
    logger.setLevel(logging.INFO)
elif logging_level == 'DEBUG':
    logger.setLevel(logging.DEBUG)

s3_client = boto3.client('s3')

delimiter = ','
batch_size = int(os.environ['SP_BATCH_SIZE'])
batch_scale = int(os.environ['SP_BATCH_SCALE'])


def lambda_handler(event, context):
    logger.debug('__EVENT: {}'.format(json.dumps(event)))
    for record in event['Records']:
        try:
            file_event_time = record['eventTime']
            bucket_name = record['s3']['bucket']['name']
            filename = record['s3']['object']['key']
            file_size = record['s3']['object']['size']
            file_etag = record['s3']['object']['eTag']
            file_seq = record['s3']['object']['sequencer']

            download_path = '/tmp/{}'.format(filename)
            s3_client.download_file(bucket_name, filename, download_path)
            with open(download_path) as infile:
                line = infile.readline()
                header = [header.strip()
                          for header in line.split(delimiter)[0:]]
                header = header[:-1]
                header.append("ZZ_FILENAME")
                header.append("ZZ_BATCH_ID")
                header.append("ZZ_PROCESSED_DATETIME")
                header.append("ZZ_RECORD_ID")
                header.append("ZZ_EVENT_TIMESTAMP_EPOC")
                idx = 0
                mod = 0
                line_len = 1

                while line_len != 0:
                    metadata = {
                        "S3_FileName": "%s" % filename,
                        "S3_FileEventDateTime": "%s" % file_event_time,
                        "S3_FileSize": "%s" % file_size,
                        "S3_FileETag": "%s" % file_etag,
                        "S3_FileSequencer": "%s" % file_seq,
                        "ZZ_BatchSize": "%s" % batch_size,
                        "ZZ_BatchScale": "%s" % batch_scale,
                        "ZZ_BatchId": "%s" % idx,
                        "ZZ_Data": []
                    }
                    payload = []
                    for i in range(batch_size):
                        line = infile.readline()
                        line_len = len(line)
                        if line_len == 0:
                            break
                        data_list = [data.strip()
                                     for data in line.split(delimiter)[0:]]
                        data_list = data_list[:-1]
                        now = datetime.utcnow()
                        record_id = str(uuid.uuid1())
                        event_timestamp = datetime.strptime(
                            data_list[4], '%Y/%m/%d %H:%M:%S.%f')
                        event_timestamp_epoc = (
                            event_timestamp - datetime(1970, 1, 1)).total_seconds()
                        data_list.append(filename)
                        data_list.append(idx)
                        data_list.append(now.isoformat())
                        data_list.append(record_id)
                        data_list.append(event_timestamp_epoc)
                        body = dict(zip(header, data_list[0:]))
                        metadata['ZZ_Data'].append(body)
                    payload.append(metadata)
                    # Just dump it out to CW for now
                    logger.info('payload: {}'.format(
                        json.dumps(payload, indent=4)))
                    mod = idx % batch_scale
                    idx += 1
        except Exception as e:
            logger.error(e)
            raise
        return 'File processed:' + str(download_path)
