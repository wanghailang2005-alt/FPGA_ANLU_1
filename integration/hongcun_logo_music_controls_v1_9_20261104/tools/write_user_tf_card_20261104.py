"""Write the user-authorized F: TF card; fixed device identity, backup, readback.

Requires Windows administrator token. Never selects a disk by size alone.
"""
from pathlib import Path
import ctypes,datetime,hashlib,json,msvcrt,os,shutil,subprocess,traceback
from ctypes import wintypes as W

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'music_evidence/tf_card_write_20261104'
OUT.mkdir(exist_ok=True)
STATUS=OUT/'status.json'
IMAGE=ROOT/'music_media/HONGCUN_CURRENT_F_2_MUSIC_20261104.img'
EXPECTED_SIZE=15634268160
EXPECTED_IMAGE_SIZE=72868864
EXPECTED_SHA='419e4c716efba77011ae72c89f06dbc7b864be8aa19b8a3b865601ec40017fd5'
EXPECTED_ID=r'USBSTOR\DISK&VEN_MASS&PROD_STORAGE_DEVICE&REV_1.00\121220160204&0:DESKTOPMV33N91'
result={}
def status(stage,**kw):
 result.update(stage=stage,time=datetime.datetime.now(datetime.timezone.utc).isoformat(),**kw)
 STATUS.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')

K=ctypes.WinDLL('kernel32',use_last_error=True)
K.CreateFileW.argtypes=[W.LPCWSTR,W.DWORD,W.DWORD,W.LPVOID,W.DWORD,W.DWORD,W.HANDLE]
K.CreateFileW.restype=W.HANDLE
K.CloseHandle.argtypes=[W.HANDLE]
K.DeviceIoControl.argtypes=[W.HANDLE,W.DWORD,W.LPVOID,W.DWORD,W.LPVOID,W.DWORD,ctypes.POINTER(W.DWORD),W.LPVOID]
K.DeviceIoControl.restype=W.BOOL
K.SetFilePointerEx.argtypes=[W.HANDLE,ctypes.c_longlong,ctypes.POINTER(ctypes.c_longlong),W.DWORD]
K.SetFilePointerEx.restype=W.BOOL
K.ReadFile.argtypes=[W.HANDLE,W.LPVOID,W.DWORD,ctypes.POINTER(W.DWORD),W.LPVOID]
K.ReadFile.restype=W.BOOL
K.WriteFile.argtypes=[W.HANDLE,W.LPCVOID,W.DWORD,ctypes.POINTER(W.DWORD),W.LPVOID]
K.WriteFile.restype=W.BOOL
K.FlushFileBuffers.argtypes=[W.HANDLE];K.FlushFileBuffers.restype=W.BOOL
K.VirtualAlloc.argtypes=[W.LPVOID,ctypes.c_size_t,W.DWORD,W.DWORD];K.VirtualAlloc.restype=W.LPVOID
K.VirtualFree.argtypes=[W.LPVOID,ctypes.c_size_t,W.DWORD]
BLOCK=65536
class RawDisk:
 def __init__(self,h):
  self.h=h;self.buffer=K.VirtualAlloc(None,BLOCK,0x3000,4)
  if not self.buffer:raise ctypes.WinError(ctypes.get_last_error())
 def read(self,n):
  assert 0<n<=BLOCK and n%512==0
  count=W.DWORD()
  if not K.ReadFile(self.h,self.buffer,n,ctypes.byref(count),None):raise ctypes.WinError(ctypes.get_last_error())
  return ctypes.string_at(self.buffer,count.value)
 def write(self,data):
  assert len(data)<=BLOCK and len(data)%512==0
  ctypes.memmove(self.buffer,data,len(data));count=W.DWORD()
  if not K.WriteFile(self.h,self.buffer,len(data),ctypes.byref(count),None):raise ctypes.WinError(ctypes.get_last_error())
  return count.value
 def seek(self,offset):
  if not K.SetFilePointerEx(self.h,offset,None,0):raise ctypes.WinError(ctypes.get_last_error())
 def flush(self):
  if not K.FlushFileBuffers(self.h):raise ctypes.WinError(ctypes.get_last_error())
 def close(self):K.CloseHandle(self.h);K.VirtualFree(self.buffer,0,0x8000)
def ioctl(handle,code,required=True):
 count=W.DWORD()
 ok=K.DeviceIoControl(handle,code,None,0,None,0,ctypes.byref(count),None)
 if not ok and required:raise ctypes.WinError(ctypes.get_last_error())
 return bool(ok)
def handle(path,access):
 h=K.CreateFileW(path,access,3,None,3,0x80000000,None)
 if h==W.HANDLE(-1).value:raise ctypes.WinError(ctypes.get_last_error())
 return h
def digest(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
 if STATUS.exists() and json.loads(STATUS.read_text(encoding='utf-8')).get('stage')=='VERIFIED':
  raise RuntimeError('This write already completed; refusing to repeat automatically.')
 status('PREFLIGHT')
 assert IMAGE.stat().st_size==EXPECTED_IMAGE_SIZE and digest(IMAGE)==EXPECTED_SHA,'Image checksum mismatch'
 query="""$ErrorActionPreference='Stop'; $p=Get-Partition -DriveLetter F; $d=Get-Disk -Number $p.DiskNumber; [pscustomobject]@{Number=$d.Number;UniqueId=$d.UniqueId;Size=$d.Size;IsBoot=$d.IsBoot;IsSystem=$d.IsSystem;IsReadOnly=$d.IsReadOnly;BusType=[string]$d.BusType;Offset=$p.Offset;PartitionCount=@(Get-Partition -DiskNumber $d.Number).Count}|ConvertTo-Json -Compress"""
 info=json.loads(subprocess.check_output(['powershell.exe','-NoProfile','-NonInteractive','-Command',query],text=True))
 assert info['Number']==2 and info['UniqueId']==EXPECTED_ID and info['Size']==EXPECTED_SIZE,info
 assert not info['IsBoot'] and not info['IsSystem'] and not info['IsReadOnly'],info
 assert info['BusType']=='USB' and info['Offset']==0 and info['PartitionCount']==1,info
 assert shutil.disk_usage(OUT).free>EXPECTED_IMAGE_SIZE+16*1024*1024,'Insufficient backup space'
 result['device']=info;result['image_sha256']=EXPECTED_SHA
 files=OUT/'files_before';files.mkdir(exist_ok=True)
 entries=[]
 for p in Path('F:/').iterdir():
  if p.is_dir():
   assert p.name=='System Volume Information',f'Unexpected user directory: {p}'
   continue
  assert p.suffix.lower()=='.bmp',f'Unexpected user file: {p}'
  dst=files/p.name
  assert not dst.exists(),f'Backup already exists: {dst}'
  shutil.copy2(p,dst)
  assert digest(p)==digest(dst)
  entries.append({'name':p.name,'bytes':p.stat().st_size,'sha256':digest(dst)})
 assert len(entries)==5,'Expected the five inspected BMP files'
 expected_files=json.loads((OUT/'image_manifest.json').read_text(encoding='utf-8'))['images']
 assert {e['name']:e['sha256'] for e in entries}=={e['name']:e['sha256'] for e in expected_files},'F: files changed since preflight'
 result['file_backups']=entries
 status('FILES_BACKED_UP')
 volume=handle(r'\\.\F:',0xC0000000)
 raw=None;locked=False;written=False;backup=OUT/f'before_first_{EXPECTED_IMAGE_SIZE}_bytes.bin'
 try:
  ioctl(volume,0x00090018);locked=True  # FSCTL_LOCK_VOLUME
  ioctl(volume,0x00090020)              # FSCTL_DISMOUNT_VOLUME
  h=handle(r'\\.\PhysicalDrive2',0xC0000000)
  raw=RawDisk(h)
  assert not backup.exists(),'Refusing to overwrite original raw backup'
  status('BACKING_UP_RAW_SECTORS')
  remaining=EXPECTED_IMAGE_SIZE;original_hash=hashlib.sha256()
  with backup.open('xb') as f:
   while remaining:
    data=raw.read(min(BLOCK,remaining))
    assert data,'Short original disk read'
    f.write(data);original_hash.update(data);remaining-=len(data)
   f.flush();os.fsync(f.fileno())
  assert digest(backup)==original_hash.hexdigest()
  result['raw_backup']=str(backup);result['raw_backup_sha256']=original_hash.hexdigest()
  status('RAW_BACKUP_VERIFIED')
  raw.seek(0);written=True
  status('WRITING_IMAGE')
  with IMAGE.open('rb') as f:
   while data:=f.read(BLOCK):
    assert raw.write(data)==len(data),'Short raw disk write'
  raw.flush()
  status('VERIFYING_CARD')
  raw.seek(0);remaining=EXPECTED_IMAGE_SIZE;card_hash=hashlib.sha256()
  while remaining:
   data=raw.read(min(BLOCK,remaining));assert data,'Short card readback'
   card_hash.update(data);remaining-=len(data)
  assert card_hash.hexdigest()==EXPECTED_SHA,'Card readback checksum mismatch'
  result['readback_sha256']=card_hash.hexdigest();result['bytes_written']=EXPECTED_IMAGE_SIZE
  result['partition_refresh_requested']=ioctl(raw.h,0x00070140,False)
  status('VERIFIED')
 except Exception:
  if written and raw and backup.exists():
   try:
    raw.seek(0)
    with backup.open('rb') as f:
     while data:=f.read(BLOCK):assert raw.write(data)==len(data)
    raw.flush();result['rollback']='original prefix restored'
   except Exception as rollback_error:result['rollback']='FAILED: '+repr(rollback_error)
  raise
 finally:
  if raw:raw.close()
  if locked:ioctl(volume,0x0009001c,False)
  K.CloseHandle(volume)

try:main()
except Exception as error:
 status('FAILED',error=repr(error),traceback=traceback.format_exc())
 raise
