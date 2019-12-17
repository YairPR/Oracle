select device_type "Device", type, filename, to_char(open_time, 'mm/dd/yyyy hh24:mi:ss') open,
 to_char(close_time,'mm/dd/yyyy hh24:mi:ss') close,elapsed_time ET, effective_bytes_per_second EPS
 from v$backup_async_io;
