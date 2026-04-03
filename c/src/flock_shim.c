/* flock_shim.c — Selective LD_PRELOAD shim with Mirror Stealth Path Redirection & Resilient mkdir. */
#define _GNU_SOURCE
#include <sys/file.h>
#include <sys/vfs.h>
#include <sys/stat.h>
#include <stddef.h>
#include <stdarg.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define REDIR_BASE "/home/guest/.vivado_local/redirection"

/* Bad filesystems (freezes Xilinx tools w/ syscall hangs) */
#define FUSE_MAGIC     0x65735546
#define NTFS3_MAGIC    0x5346544e
#define V9FS_MAGIC     0x01021997

static int (*real_flock)(int fd, int operation) = NULL;
static int (*real_fcntl)(int fd, int cmd, ...) = NULL;
static int (*real_open)(const char *pathname, int flags, ...) = NULL;
static int (*real_open64)(const char *pathname, int flags, ...) = NULL;
static int (*real_openat)(int dirfd, const char *pathname, int flags, ...) = NULL;
static int (*real_stat)(const char *pathname, struct stat *statbuf) = NULL;
static int (*real_lstat)(const char *pathname, struct stat *statbuf) = NULL;
static int (*real_execve)(const char *filename, char *const argv[], char *const envp[]) = NULL;
static int (*real_mkdir)(const char *pathname, mode_t mode) = NULL;
static int (*real_unlink)(const char *pathname) = NULL;
static int (*real_rmdir)(const char *pathname) = NULL;
static int (*real_rename)(const char *oldpath, const char *newpath) = NULL;
static int (*real_access)(const char *pathname, int mode) = NULL;
static int (*real_chmod)(const char *pathname, mode_t mode) = NULL;

static void ensure_parent_exists(const char *path) {
    char tmp[1024]; char *p = NULL; size_t len;
    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp); if (tmp[len - 1] == '/') tmp[len - 1] = 0;
    for (p = tmp + 1; *p; p++) {
        if (*p == '/') { *p = 0; mkdir(tmp, 0777); *p = '/'; }
    }
}

__attribute__((constructor))
static void init_shim() {
    real_flock  = dlsym(RTLD_NEXT, "flock");
    real_fcntl  = dlsym(RTLD_NEXT, "fcntl");
    real_open   = dlsym(RTLD_NEXT, "open");
    real_open64 = dlsym(RTLD_NEXT, "open64");
    real_openat = dlsym(RTLD_NEXT, "openat");
    real_stat   = dlsym(RTLD_NEXT, "stat");
    real_lstat  = dlsym(RTLD_NEXT, "lstat");
    real_execve = dlsym(RTLD_NEXT, "execve");
    real_mkdir  = dlsym(RTLD_NEXT, "mkdir");
    real_unlink = dlsym(RTLD_NEXT, "unlink");
    real_rmdir  = dlsym(RTLD_NEXT, "rmdir");
    real_rename = dlsym(RTLD_NEXT, "rename");
    real_access = dlsym(RTLD_NEXT, "access");
    real_chmod  = dlsym(RTLD_NEXT, "chmod");
    mkdir(REDIR_BASE, 0777);
}

static const char* redirect_path(const char *path, char *buf, size_t buflen) {
    if (!path || !strstr(path, "/workspace/")) return path;
    if (strstr(path, "/_xmsgs") || strstr(path, "/isim") || strstr(path, "/xlnx_auto_0_xdb")) {
        snprintf(buf, buflen, "%s%s", REDIR_BASE, path);
        return buf;
    }
    return path;
}

int open(const char *pathname, int flags, ...) {
    mode_t mode = 0; if (flags & O_CREAT) { va_list a; va_start(a, flags); mode = va_arg(a, mode_t); va_end(a); }
    char buf[1024]; const char *p = redirect_path(pathname, buf, sizeof(buf));
    if (p != pathname && (flags & O_CREAT)) ensure_parent_exists(p);
    if (!real_open) real_open = dlsym(RTLD_NEXT, "open");
    return real_open(p, flags, mode);
}

int open64(const char *pathname, int flags, ...) {
    mode_t mode = 0; if (flags & O_CREAT) { va_list a; va_start(a, flags); mode = va_arg(a, mode_t); va_end(a); }
    char buf[1024]; const char *p = redirect_path(pathname, buf, sizeof(buf));
    if (p != pathname && (flags & O_CREAT)) ensure_parent_exists(p);
    if (!real_open64) real_open64 = dlsym(RTLD_NEXT, "open64");
    return real_open64(p, flags, mode);
}

int openat(int dirfd, const char *pathname, int flags, ...) {
    mode_t mode = 0; if (flags & O_CREAT) { va_list a; va_start(a, flags); mode = va_arg(a, mode_t); va_end(a); }
    char buf[1024]; const char *p = redirect_path(pathname, buf, sizeof(buf));
    if (p != pathname && (flags & O_CREAT)) ensure_parent_exists(p);
    if (!real_openat) real_openat = dlsym(RTLD_NEXT, "openat");
    return real_openat(dirfd, p, flags, mode);
}

int mkdir(const char *pathname, mode_t mode) {
    if (!real_mkdir) real_mkdir = dlsym(RTLD_NEXT, "mkdir");
    char buf[1024]; const char *p = redirect_path(pathname, buf, sizeof(buf));
    if (p != pathname) ensure_parent_exists(p);
    int res = real_mkdir(p, mode);
    // Be a Helpful Liar: if the directory already exists, tell legacy tools it was a success.
    if (res == -1 && errno == EEXIST) return 0;
    return res;
}

int unlink(const char *path) { char b[1024]; if(!real_unlink) real_unlink=dlsym(RTLD_NEXT,"unlink"); return real_unlink(redirect_path(path,b,sizeof(b))); }
int rmdir(const char *path) { char b[1024]; if(!real_rmdir) real_rmdir=dlsym(RTLD_NEXT,"rmdir"); return real_rmdir(redirect_path(path,b,sizeof(b))); }
int access(const char *path, int mode) { char b[1024]; if(!real_access) real_access=dlsym(RTLD_NEXT,"access"); return real_access(redirect_path(path,b,sizeof(b)),mode); }
int chmod(const char *path, mode_t mode) { char b[1024]; if(!real_chmod) real_chmod=dlsym(RTLD_NEXT,"chmod"); return real_chmod(redirect_path(path,b,sizeof(b)),mode); }

int rename(const char *oldpath, const char *newpath) {
    char b1[1024], b2[1024]; const char *p2 = redirect_path(newpath, b2, sizeof(b2));
    if (p2 != newpath) ensure_parent_exists(p2);
    if(!real_rename) real_rename=dlsym(RTLD_NEXT,"rename");
    return real_rename(redirect_path(oldpath, b1, sizeof(b1)), p2);
}

int stat(const char *path, struct stat *s) { char b[1024]; if(!real_stat) real_stat=dlsym(RTLD_NEXT,"stat"); return real_stat(redirect_path(path,b,sizeof(b)),s); }
int lstat(const char *path, struct stat *s) { char b[1024]; if(!real_lstat) real_lstat=dlsym(RTLD_NEXT,"lstat"); return real_lstat(redirect_path(path,b,sizeof(b)),s); }
int __xstat(int v, const char *p, struct stat *s) { char b[1024]; return ((int (*)(int, const char*, struct stat*))dlsym(RTLD_NEXT, "__xstat"))(v, redirect_path(p,b,sizeof(b)), s); }
int __lxstat(int v, const char *p, struct stat *s) { char b[1024]; return ((int (*)(int, const char*, struct stat*))dlsym(RTLD_NEXT, "__lxstat"))(v, redirect_path(p,b,sizeof(b)), s); }
int __xstat64(int v, const char *p, struct stat *s) { char b[1024]; return ((int (*)(int, const char*, struct stat*))dlsym(RTLD_NEXT, "__xstat64"))(v, redirect_path(p,b,sizeof(b)), s); }
int __lxstat64(int v, const char *p, struct stat *s) { char b[1024]; return ((int (*)(int, const char*, struct stat*))dlsym(RTLD_NEXT, "__lxstat64"))(v, redirect_path(p,b,sizeof(b)), s); }

int execve(const char *filename, char *const argv[], char *const envp[]) {
    if (!real_execve) real_execve = dlsym(RTLD_NEXT, "execve");
    struct statfs b;
    if (filename && statfs(filename, &b) == 0) {
        int bad = (b.f_type == FUSE_MAGIC || b.f_type == NTFS3_MAGIC || b.f_type == V9FS_MAGIC);
        if (bad && (strstr(filename, ".exe") || strstr(filename, "isim"))) {
             char t[512]; const char *base = strrchr(filename, '/'); base = base ? base + 1 : filename;
             snprintf(t, sizeof(t), "/home/guest/.vivado_local/exec_redir_%s", base);
             char *pr = getenv("LD_PRELOAD"); char *s = pr ? strdup(pr) : NULL; unsetenv("LD_PRELOAD");
             char cmd[1024]; snprintf(cmd, sizeof(cmd), "cp -f \"%s\" \"%s\" && chmod +x \"%s\"", filename, t, t);
             int res = system(cmd);
             if (s) { setenv("LD_PRELOAD", s, 1); free(s); }
             if (res == 0) return real_execve(t, argv, envp);
        }
    }
    return real_execve(filename, argv, envp);
}

int flock(int fd, int op) {
    if (!real_flock) real_flock = dlsym(RTLD_NEXT, "flock");
    struct statfs b; if (fstatfs(fd, &b) == 0) {
        if (b.f_type == FUSE_MAGIC || b.f_type == NTFS3_MAGIC || b.f_type == V9FS_MAGIC) return 0;
    }
    return real_flock(fd, op);
}

int fcntl(int fd, int cmd, ...) {
    if (!real_fcntl) real_fcntl = dlsym(RTLD_NEXT, "fcntl");
    va_list ap; va_start(ap, cmd); void *arg = va_arg(ap, void *); va_end(ap);
    if (cmd == F_SETLK || cmd == F_SETLKW || cmd == F_GETLK) {
        struct statfs b; if (fstatfs(fd, &b) == 0) {
            if (b.f_type == FUSE_MAGIC || b.f_type == NTFS3_MAGIC || b.f_type == V9FS_MAGIC) return 0;
        }
    }
    return real_fcntl(fd, cmd, arg);
}