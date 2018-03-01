import os
import json
import boto3
import logging
from datetime import datetime

logger = logging.getLogger()
logging_level = os.environ['SP_LOGGING_LEVEL']

if logging_level == 'WARN':
    logger.setLevel(logging.WARN)
elif logging_level == 'INFO':
    logger.setLevel(logging.INFO)
elif logging_level == 'DEBUG':
    logger.setLevel(logging.DEBUG)

sp_delimiter = ','
sp_batch_size = int(os.environ['SP_BATCH_SIZE'])
sp_batch_scale = int(os.environ['SP_BATCH_SCALE'])

# Default session
s3_client = boto3.client('s3')
ddb = boto3.resource('dynamodb')

bl_edr = ddb.Table('BL_EDR')
# bl_edr_dup = ddb.Table('BL_EDR_DUP')


def send_to_ddb(data):
    logger.debug('__data: {}'.format(json.dumps(data)))
    try:
        with bl_edr.batch_writer() as batch:
            for record in data[0]['ZZ_Data']:
                batch.put_item(Item=record)
    except Exception as e:
        logger.error(e)
        raise e


def lambda_handler(event, context):
    logger.debug('__event: {}'.format(json.dumps(event)))
    for record in event['Records']:
        try:
            record_count = 0
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
                          for header in line.split(sp_delimiter)[0:]]
                header = header[:-1]
                header.append("ZZ_FILENAME")
                header.append("ZZ_BATCH_ID")
                header.append("ZZ_PROCESSED_DATETIME")
                header.append("ZZ_PARTITION_KEY")
                header.append("ZZ_EVENT_TS_ISO")
                header.append("ZZ_EVENT_TS_EPOC")
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
                        "ZZ_BatchSize": "%s" % sp_batch_size,
                        "ZZ_BatchScale": "%s" % sp_batch_scale,
                        "ZZ_BatchId": "%s" % idx,
                        "ZZ_Data": []
                    }
                    payload = []
                    for i in range(sp_batch_size):
                        line = infile.readline()
                        line_len = len(line)
                        if line_len == 0:
                            break
                        data_list = [data.strip()
                                     for data in line.split(sp_delimiter)[0:]]
                        data_list = data_list[:-1]
                        now = datetime.utcnow()
                        event_ts = datetime.strptime(
                            data_list[4], '%Y/%m/%d %H:%M:%S.%f')

                        # composite key items
                        division_id = data_list[6]
                        subscriber_id = data_list[8]
                        subscriber_type = data_list[9]
                        device_id = data_list[10]
                        partition_key = '{}|{}|{}|{}'.format(
                            device_id,
                            subscriber_id,
                            subscriber_type,
                            division_id
                        )

                        event_ts_epoc = (
                            event_ts - datetime(1970, 1, 1)).total_seconds()
                        data_list.append(filename)
                        data_list.append(idx)
                        data_list.append(now.isoformat())
                        data_list.append(partition_key)
                        data_list.append(str(event_ts.isoformat()))
                        data_list.append(str(event_ts_epoc))
                        body = dict(zip(header, data_list[0:]))
                        metadata['ZZ_Data'].append(body)
                        record_count += 1
                    payload.append(metadata)
                    send_to_ddb(payload)
                    mod = idx % sp_batch_scale
                    idx += 1
        except Exception as e:
            logger.error(e)
            raise e

        return_msg = 'File processed: {} | File size: {} | Total records: {}'.format(
            filename, file_size, record_count)
        return return_msg
