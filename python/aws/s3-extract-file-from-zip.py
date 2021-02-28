import sys
import zlib
import zipfile
import io

import boto
from boto.s3.connection import OrdinaryCallingFormat


# range-fetches a S3 key
def fetch(key, start, len):
    end = start + len - 1
    return key.get_contents_as_string(headers={"Range": "bytes=%d-%d" % (start, end)})


# parses 2 or 4 little-endian bits into their corresponding integer value
def parse_int(bytes):
    val = ord(bytes[0]) + (ord(bytes[1]) << 8)
    if len(bytes) > 3:
        val += (ord(bytes[2]) << 16) + (ord(bytes[3]) << 24)
    return val


bucket = ''
key = ''
entry = ""

# OrdinaryCallingFormat prevents certificate errors on bucket names with dots
# https://stackoverflow.com/questions/51604689/read-zip-files-from-amazon-s3-using-boto3-and-python#51605244
_bucket = boto.connect_s3(calling_format=OrdinaryCallingFormat()).get_bucket(bucket)
_key = _bucket.get_key(key)

# fetch the last 22 bytes (end-of-central-directory record; assuming the comment field is empty)
size = _key.size
eocd = fetch(_key, size - 22, 22)

# start offset and size of the central directory
cd_start = parse_int(eocd[16:20])
cd_size = parse_int(eocd[12:16])

# fetch central directory, append EOCD, and open as zipfile
cd = fetch(_key, cd_start, cd_size)
zip = zipfile.ZipFile(io.BytesIO(cd + eocd))


for zi in zip.filelist:
    if zi.filename == entry:
        # local file header starting at file name length + file content
        # (so we can reliably skip file name and extra fields)

        # in our "mock" zipfile, `header_offset`s are negative (probably because the leading content is missing)
        # so we have to add to it the CD start offset (`cd_start`) to get the actual offset

        file_head = fetch(_key, cd_start + zi.header_offset + 26, 4)
        name_len = parse_int(file_head[0:2])
        extra_len = parse_int(file_head[2:4])

        content = fetch(_key, cd_start + zi.header_offset + 30 + name_len + extra_len, zi.compress_size)

        # now `content` has the file entry you were looking for!
        # you should probably decompress it in context before passing it to some other program

        if zi.compress_type == zipfile.ZIP_DEFLATED:
            print(zlib.decompressobj(-15).decompress(content))
        else:
            print(content)
        break