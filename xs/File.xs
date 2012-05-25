#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <sys/stat.h>
#include <sys/types.h>
#include <windows.h>

#ifdef __CYGWIN__
    #define _STAT(file, st) stat(file, st)
    #define _UTIME(file, st) utime(file, st)
#else
    #define _STAT(file, st) _wstat(file, st)
    #define _UTIME(file, st) _wutime(file, st)
#endif

WINBASEAPI BOOL WINAPI GetFileSizeEx(HANDLE,PLARGE_INTEGER);


MODULE = Win32::Unicode::File   PACKAGE = Win32::Unicode::File

PROTOTYPES: DISABLE

HANDLE
create_file(SV* file, long amode, long smode, long opt, long attr)
    CODE:
        const wchar_t *file_name = (wchar_t *)SvPV_nolen(file);
        RETVAL = CreateFileW(
            file_name,
            amode,
            smode,
            NULL,
            opt,
            attr,
            NULL
        );
    OUTPUT:
        RETVAL

void
win32_read_file(HANDLE handle, unsigned long count)
    CODE:
        char buff[count];
        bool has_error = 0;
        unsigned long len;
        if (!ReadFile(handle, buff, count, &len, NULL)) {
            if (GetLastError() != NO_ERROR) {
                has_error = 1;
                len = 0;
            }
            else {
                len = 0;
            }
        }
        buff[len] = '\0';
        
        ST(0) = newSViv(has_error ? -1 : len);
        ST(1) = newSVpv(buff, 0);
        XSRETURN(2);

void
win32_write_file(HANDLE handle, char *buff, unsigned long size)
    CODE:
        long len;
        if (!WriteFile(handle, buff, size, &len, NULL)) {
            if (GetLastError() != NO_ERROR) {
                len = -1;
            }
            else {
                len = 0;
            }
        }
        
        ST(0) = newSViv(len);
        XSRETURN(1);

int
delete_file(SV* file)
    CODE:
        const wchar_t *file_name = (wchar_t *)SvPV_nolen(file);
        RETVAL = DeleteFileW(file_name);
    OUTPUT:
        RETVAL

long
get_file_attributes(SV* file)
    CODE:
        const wchar_t *file_name = (wchar_t *)SvPV_nolen(file);
        RETVAL = GetFileAttributesW(file_name);
    OUTPUT:
        RETVAL

void
get_file_size(HANDLE handle)
    CODE:
        LARGE_INTEGER st;
        SV* sv = sv_2mortal(newSV(0));
        HV* hv = sv_2mortal(newHV());
        
        if (GetFileSizeEx(handle, &st) == 0) {
            XSRETURN_EMPTY;
        }
        
        sv_setsv(sv, newRV_noinc((SV*)hv));
        hv_stores(hv, "high", newSVnv(st.HighPart));
        hv_stores(hv, "low", newSVnv(st.LowPart));
        
        ST(0) = sv;
        XSRETURN(1);

bool
copy_file(SV* from, SV* to, int over)
    CODE:
        const wchar_t *from_name = (wchar_t *)SvPV_nolen(from);
        const wchar_t *to_name   = (wchar_t *)SvPV_nolen(to);
        
        RETVAL = CopyFileW(from_name, to_name, over);
    OUTPUT:
        RETVAL

bool
move_file(SV* from, SV* to)
    CODE:
        const wchar_t *from_name = (wchar_t *)SvPV_nolen(from);
        const wchar_t *to_name   = (wchar_t *)SvPV_nolen(to);
        
        RETVAL = MoveFileW(from_name, to_name);
    OUTPUT:
        RETVAL

void
set_file_pointer(HANDLE handle, long lpos, long hpos, int whence)
    CODE:
        LARGE_INTEGER mv;
        LARGE_INTEGER st;
        SV* sv = sv_2mortal(newSV(0));
        HV* hv = sv_2mortal(newHV());
        
        mv.LowPart  = lpos;
        mv.HighPart = hpos;
        
        if (SetFilePointerEx(handle, mv, &st, whence) == 0) {
            XSRETURN_EMPTY;
        }
        
        sv_setsv(sv, newRV_noinc((SV*)hv));
        hv_stores(hv, "high", newSVnv(st.HighPart));
        hv_stores(hv, "low", newSVnv(st.LowPart));
        
        ST(0) = sv;
        XSRETURN(1);

void
get_stat_data(SV* file, HANDLE handle, int is_dir)
    CODE:
        struct _stat st;
        BY_HANDLE_FILE_INFORMATION fi;
        SV* sv = sv_2mortal(newSV(0));
        HV* hv = sv_2mortal(newHV());
        const wchar_t *file_name = (wchar_t *)SvPV_nolen(file);
        
        if (_STAT(file_name, &st) != 0) {
            XSRETURN_EMPTY;
        }
        
        if (!is_dir) {
            if (GetFileInformationByHandle(handle, &fi) == 0) {
                XSRETURN_EMPTY;
            }
        }
        
        sv_setsv(sv, newRV_noinc((SV*)hv));
        hv_stores(hv, "dev", newSViv(st.st_dev));
        hv_stores(hv, "ino", newSViv(st.st_ino));
        hv_stores(hv, "mode", newSViv(st.st_mode));
        hv_stores(hv, "nlink", newSViv(st.st_nlink));
        hv_stores(hv, "uid", newSViv(st.st_uid));
        hv_stores(hv, "gid", newSViv(st.st_gid));
        hv_stores(hv, "rdev", newSViv(st.st_rdev));
        hv_stores(hv, "atime", newSViv(st.st_atime));
        hv_stores(hv, "mtime", newSViv(st.st_mtime));
        hv_stores(hv, "ctime", newSViv(st.st_ctime));
#ifdef __CYGWIN__
        hv_stores(hv, "blksize", newSViv(st.st_blksize));
        hv_stores(hv, "blocks", newSViv(st.st_blocks));
#endif
        if (is_dir) {
            hv_stores(hv, "size_high", newSViv(0));
            hv_stores(hv, "size_low", newSViv(0));
        }
        else {
            hv_stores(hv, "size_high", newSViv(fi.nFileSizeHigh));
            hv_stores(hv, "size_low", newSViv(fi.nFileSizeLow));
        }
        
        ST(0) = sv;
        XSRETURN(1);

bool
lock_file(HANDLE handle, int ope)
    CODE:
        long option = 0;
        OVERLAPPED ol;
        ol.Offset = 0;
        ol.OffsetHigh = 0;
        
        switch(ope) {
            case 1:
                break;
            case 2:
                option = LOCKFILE_EXCLUSIVE_LOCK;
                break;
            case 5:
                option = LOCKFILE_FAIL_IMMEDIATELY;
                break;
            case 6:
                option = LOCKFILE_FAIL_IMMEDIATELY | LOCKFILE_EXCLUSIVE_LOCK;
                break;
            default:
                XSRETURN_EMPTY;
                break;
        }
        
        RETVAL = LockFileEx(handle, option, 0, 0xFFFFFFFF, 0xFFFFFFFF, &ol);
    OUTPUT:
        RETVAL

bool
unlock_file(HANDLE handle)
    CODE:
        OVERLAPPED ol;
        ol.Offset = 0;
        ol.OffsetHigh = 0;
        
        RETVAL = UnlockFileEx(handle, 0, 0xFFFFFFFF, 0xFFFFFFFF, &ol);
    OUTPUT:
        RETVAL

bool
update_time(long atime, long mtime, SV* file)
    CODE:
        struct _utimbuf ut;
        const wchar_t *file_name = (wchar_t *)SvPV_nolen(file);
        
        ut.actime  = atime;
        ut.modtime = mtime;
        
        if (_UTIME(file_name, &ut) == -1) {
            XSRETURN_EMPTY;
        }
        
        RETVAL = 1;
    OUTPUT:
        RETVAL
