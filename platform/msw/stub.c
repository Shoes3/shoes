#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

#define LONG_LONG long long
#define SHOES_TIME DWORD
#define SHOES_DOWNLOAD_ERROR DWORD

#include "shoes/version.h"
#include "shoes/internal.h"
#include "shoes/http/winhttp.h"
#include "stub32.h"

#define BUFSIZE 512

HWND dlg;
BOOL http_abort = FALSE;
WCHAR download_site[256];
WCHAR download_path[256];

/*
 * Note by Cecil (aka cjc)
 * This code used to use resources that could be Found with a 'string'
 * name. That was clever but was too clever to maintain crosss platform
 * The code below Locates resources by id number (see stub32.h, stub32.rc 
 * and winject.rb
 * 
 * The string contents of the new resources are UTF-16 (wide characters 
 * in Windows Speak) which have a pascal like count in the first character
 * position (a DWORD) of the string (and perhaps no trailing null char);
 * This introduces some odd character-ptr +1 or +2 adjustments. 
 * Sorry about that.
 * 
 * It's a mix of normal C, wide C, and Microsoft Weirdness.
 * It's compiled with UNICODE being #defined OFF
 * 
 * Someone should fix this mess. 
*/

/*
 * find and load a String resource, convert it from utf-16le to
 * UTF-8 and or Ascii 8 bit (null terminated string). Alloc from the heap.
 * Caller will have to free() it, as if someone cares.
 * 
 * I am concerned that the reported lengths are several times larger
 * than the string and skipping the first byte is clearly a hack.
 * -- cjc
*/
char * shoes_str_load(HINSTANCE inst, UINT resnum) 
{
  HRSRC res;
  char msg[256];
  res = FindResource(inst, MAKEINTRESOURCE(resnum), RT_STRING);
  if (res == NULL) return NULL;
  HGLOBAL sres = LoadResource(inst, res);  
  LPVOID data = LockResource(sres);
  int len = SizeofResource(inst, res);
  int olen;
  olen =  WideCharToMultiByte(CP_UTF8, 0, data, len, msg, 256,
    NULL, 0);
#ifdef SHOES_STR_DEBUG
  char buf[256];
  sprintf(buf, "Unicode OFF: %d %d %s", len, olen, msg+1);
  char *s = malloc(strlen(buf)+1);
  strcpy(s, buf);	
#else
  char *s = malloc(olen+1);
  strncpy(s, msg+1, olen);
#endif
  return s;
}


int
StubDownloadingShoes(shoes_http_event *event, void *data)
{
  TCHAR msg[512];
  if (http_abort) return SHOES_DOWNLOAD_HALT;
  if (event->stage == SHOES_HTTP_TRANSFER)
  {
    sprintf(msg, "Shoes is downloading. (%d%% done)", (int)event->percent);
    SetDlgItemText(dlg, IDSHOE, msg);
    SendMessage(GetDlgItem(dlg, IDPROG), PBM_SETPOS, event->percent, 0L);
  }
  return SHOES_DOWNLOAD_CONTINUE;
}

void
CenterWindow(HWND hwnd)
{
  RECT rc;
  
  GetWindowRect (hwnd, &rc);
  
  SetWindowPos(hwnd, 0, 
    (GetSystemMetrics(SM_CXSCREEN) - rc.right)/2,
    (GetSystemMetrics(SM_CYSCREEN) - rc.bottom)/2,
     0, 0, SWP_NOZORDER|SWP_NOSIZE );
}

BOOL CALLBACK
stub_win32proc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
  switch (message)
  {
    case WM_INITDIALOG:
      CenterWindow(hwnd);
      return TRUE;

    case WM_COMMAND:
      if (LOWORD(wParam) == IDCANCEL)
      {
        http_abort = TRUE;
        EndDialog(hwnd, LOWORD(wParam));
        return TRUE;
      }
      break;

    case WM_CLOSE:
      http_abort = TRUE;
      EndDialog(hwnd, 0);
      return FALSE;
  }
  return FALSE;
}

void
shoes_silent_install(TCHAR *path)
{
  SHELLEXECUTEINFO shell = {0};
  SetDlgItemText(dlg, IDSHOE, "Setting up Shoes...");
  shell.cbSize = sizeof(SHELLEXECUTEINFO);
  shell.fMask = SEE_MASK_NOCLOSEPROCESS;
  shell.hwnd = NULL;
  shell.lpVerb = NULL;
  shell.lpFile = path;
  shell.lpParameters = "/S"; 
  shell.lpDirectory = NULL;
  shell.nShow = SW_SHOW;
  shell.hInstApp = NULL; 
  ShellExecuteEx(&shell);
  WaitForSingleObject(shell.hProcess,INFINITE);
}

char *setup_exe = "shoes-setup.exe";

DWORD WINAPI
#ifdef __cplusplus
shoes_auto_setup(IN DWORD mid, IN WPARAM w, LPARAM &l, IN LPVOID vinst)
#else
shoes_auto_setup(IN DWORD mid, IN WPARAM w, LPARAM l, IN LPVOID vinst)
#endif
{
  HINSTANCE inst = (HINSTANCE)vinst;
  TCHAR setup_path[BUFSIZE];
  GetTempPath(BUFSIZE, setup_path);
  strncat(setup_path, setup_exe, strlen(setup_exe));

  HANDLE install = CreateFile(setup_path, GENERIC_READ | GENERIC_WRITE,
    FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
  HRSRC setupres = FindResource(inst, "SHOES_SETUP", RT_RCDATA);
  if (setupres == NULL) {
	setupres = FindResource(inst, MAKEINTRESOURCE(SHOES_SYS_SETUP), RT_RCDATA);
  }
  DWORD len = 0, rlen = 0;
  LPVOID data = NULL;
  len = SizeofResource(inst, setupres);
  if (GetFileSize(install, NULL) != len)
  {
    HGLOBAL resdata = LoadResource(inst, setupres);
    data = LockResource(resdata);
    SetFilePointer(install, 0, 0, FILE_BEGIN);
    SetEndOfFile(install);
    WriteFile(install, (LPBYTE)data, len, &rlen, NULL);
  }
  CloseHandle(install);
  SendMessage(GetDlgItem(dlg, IDPROG), PBM_SETPOS, 50, 0L);

  shoes_silent_install(setup_path);
  return 0;
}

DWORD WINAPI
#ifdef __cplusplus
shoes_http_thread(IN DWORD mid, IN WPARAM w, LPARAM &l, IN LPVOID data)
#else
shoes_http_thread(IN DWORD mid, IN WPARAM w, LPARAM l, IN LPVOID data)
#endif
{
  DWORD len = 0;
  WCHAR path[BUFSIZE];
  TCHAR *buf = SHOE_ALLOC_N(TCHAR, BUFSIZE);
  TCHAR *empty = NULL;
  HANDLE file;
  TCHAR *nl;
  TCHAR setup_path[BUFSIZE];
  GetTempPath(BUFSIZE, setup_path);
  strncat(setup_path, setup_exe, strlen(setup_exe));
  
 
  /*
  shoes_winhttp(NULL, L"www.rin-shun.com", 80, L"/pkg/win32/shoes",
    NULL, NULL, NULL, 0, &buf, BUFSIZE,
    INVALID_HANDLE_VALUE, &len, SHOES_DL_DEFAULTS, NULL, NULL);
  */
  shoes_winhttp(NULL, download_site, 80, download_path,
    NULL, NULL, NULL, 0, &buf, BUFSIZE,
    INVALID_HANDLE_VALUE, &len, SHOES_DL_DEFAULTS, NULL, NULL);
  if (len == 0)
    return 0;

  nl = strstr(buf, "\n");
  if (nl) nl[0] = '\0';

  len = 0;
  MultiByteToWideChar(CP_ACP, 0, buf, -1, path, BUFSIZE);
  
  file = CreateFile(setup_path, GENERIC_READ | GENERIC_WRITE,
    FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  /*
  shoes_winhttp(NULL, L"www.rin-shun.com", 80, path,
    NULL, NULL, NULL, 0, &empty, 0, file, &len,
    SHOES_DL_DEFAULTS, HTTP_HANDLER(StubDownloadingShoes), NULL);
  */
  shoes_winhttp(NULL, download_site, 80, path,
    NULL, NULL, NULL, 0, &empty, 0, file, &len,
    SHOES_DL_DEFAULTS, HTTP_HANDLER(StubDownloadingShoes), NULL);  CloseHandle(file);

  shoes_silent_install(setup_path);
  return 0;
}

static BOOL
file_exists(char *fname)
{
  WIN32_FIND_DATA data;
  if (FindFirstFile(fname, &data) != INVALID_HANDLE_VALUE)
    return !(data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
  return FALSE;
}

static BOOL
reg_s(HKEY key, char* sub_key, char* val, LPBYTE data, LPDWORD data_len) {
  HKEY hkey;
  //BOOL ret = FALSE;
  LONG retv;

  retv = RegOpenKeyEx(key, sub_key, 0, KEY_QUERY_VALUE, &hkey);
  if (retv == ERROR_SUCCESS)
  {
    retv = RegQueryValueEx(hkey, val, NULL, NULL, data, data_len);
    if (retv == ERROR_SUCCESS)
      return TRUE;
  }
  return FALSE;
}


int WINAPI
WinMain(HINSTANCE inst, HINSTANCE inst2, LPSTR arg, int style)
{
  HRSRC nameres, shyres, setupres, dnlsiteres, dnlpathres, replres;
  DWORD len = 0, rlen = 0, tid = 0;
  LPVOID data = NULL;
  TCHAR buf[BUFSIZE], path[BUFSIZE], cmd[BUFSIZE];
  HKEY hkey;
  BOOL shoes;
  DWORD plen;
  HANDLE payload, th;
  MSG msg;
  char *key = "SOFTWARE\\Hackety.org\\Shoes";
  //char *key = "Software\\Hackety.org\\Shoes";
 
  
  // Allow old String lookups first, then id# 
  nameres = FindResource(inst, "SHOES_FILENAME", RT_STRING);
  if (nameres == NULL) {
    nameres = FindResource(inst, MAKEINTRESOURCE(SHOES_APP_NAME), RT_STRING);
  }
  shyres = FindResource(inst, "SHOES_PAYLOAD", RT_RCDATA);
  if (shyres == NULL) {
    shyres = FindResource(inst, MAKEINTRESOURCE(SHOES_APP_CONTENT), RT_RCDATA);
  }
    
  if (nameres == NULL || shyres == NULL)
  {
	// Test - find a numbered resource

    if (nameres == NULL) {
	  MessageBox(NULL, "No Filename", "Magic Happens!!", MB_OK);
	  return 0;
    } else {
      // MessageBox(NULL, "This is an empty Shoes stub.", "shoes!! feel yeah!!", MB_OK);
      MessageBox(NULL, "Missing contents", "shoes!! feel yeah!!", MB_OK);
     return 0;
    }
  }

  setupres = FindResource(inst, "SHOES_SETUP", RT_RCDATA);  //msvc way
  if (setupres == NULL) {
    setupres = FindResource(inst, MAKEINTRESOURCE(SHOES_SYS_SETUP), RT_RCDATA);
  }
  plen = sizeof(path);
  if (!(shoes = reg_s((hkey=HKEY_LOCAL_MACHINE), key, "", (LPBYTE)&path, &plen)))
    shoes = reg_s((hkey=HKEY_CURRENT_USER), key, "", (LPBYTE)&path, &plen);

  if (shoes)
  {
    //sprintf(cmd, "%s\\shoes.exe", path);
    //printf("bfr: %s\n", cmd);
    //if (!file_exists(cmd)) shoes = FALSE;
    //memset(cmd, 0, BUFSIZE);
    if (!file_exists(path)) shoes = FALSE;
    memset(cmd, 0, BUFSIZE);
  }

  if (!shoes)
  {
	/*
	 * Need to download Shoes installer. Get the site and path
	 * from the resources and stuff in globals vars - wide strings
	*/
	LPVOID tmpptr;
	int tlen;
	dnlsiteres = FindResource(inst, MAKEINTRESOURCE(SHOES_DOWNLOAD_SITE), RT_STRING);
	tmpptr = LoadResource(inst, dnlsiteres);
    tlen = SizeofResource(inst, dnlsiteres);
    wcscpy(download_site, tmpptr+2); // cjc: I hate that +2 offset hack

	dnlpathres = FindResource(inst, MAKEINTRESOURCE(SHOES_DOWNLOAD_PATH), RT_STRING);
	tmpptr = LoadResource(inst, dnlpathres);
    tlen = SizeofResource(inst, dnlpathres);
    wcscpy(download_path, tmpptr+2); // more hack

    
    LPTHREAD_START_ROUTINE back_action = (LPTHREAD_START_ROUTINE)shoes_auto_setup;

    INITCOMMONCONTROLSEX InitCtrlEx;
    InitCtrlEx.dwSize = sizeof(INITCOMMONCONTROLSEX);
    InitCtrlEx.dwICC = ICC_PROGRESS_CLASS;
    InitCommonControlsEx(&InitCtrlEx);

    dlg = CreateDialog(inst, MAKEINTRESOURCE(ASKDLG), NULL, stub_win32proc);
    ShowWindow(dlg, SW_SHOW);

    if (setupres == NULL)
      back_action = (LPTHREAD_START_ROUTINE)shoes_http_thread;

    if (!(th = CreateThread(0, 0, back_action, inst, 0, &tid)))
      return 0;

    while (WaitForSingleObject(th, 10) != WAIT_OBJECT_0)   
    {       
       //while (PeekMessage(&msg, NULL, NULL, NULL, PM_REMOVE))         
       while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))         
       {            
            TranslateMessage(&msg);           
            DispatchMessage(&msg);         
        }        
    }
    CloseHandle(th);

    if (!(shoes = reg_s((hkey=HKEY_LOCAL_MACHINE), key, "", (LPBYTE)&path, &plen)))
      shoes = reg_s((hkey=HKEY_CURRENT_USER), key, "", (LPBYTE)&path, &plen);
  }

  if (shoes)
  {
    GetTempPath(BUFSIZE, buf);
	/* the things we do for happy users - bug #110 */
	int bufpos = 0;

    char *str = shoes_str_load(inst, SHOES_APP_NAME);
    strcat(buf, (LPTSTR)str);

    // copy payload to temp
    payload = CreateFile(buf, GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    len = SizeofResource(inst, shyres);
    if (GetFileSize(payload, NULL) != len)
    {
      HGLOBAL resdata = LoadResource(inst, shyres);
      data = LockResource(resdata);
      SetFilePointer(payload, 0, 0, FILE_BEGIN);
      SetEndOfFile(payload);
      WriteFile(payload, (LPBYTE)data, len, &rlen, NULL);
    }
    CloseHandle(payload);
    // Now build a commandline args for Execute 
    char cmdargs[BUFSIZE];
 	replres = FindResource(inst, MAKEINTRESOURCE(SHOES_USE_ARGS), RT_STRING);
	if (replres != NULL) 
	{
	  char *args = shoes_str_load(inst, SHOES_USE_ARGS);
	  strcpy(cmdargs,args);
	  strcat(cmdargs," ");
	  strcat(cmdargs,buf);
    } else {
	  strcpy(cmdargs, buf);
    }   
    
    
#ifdef STUB_DEBUG    
    printf("payload %s, len: %d\n", cmdargs, (int)len);
    printf("cmd: %s\n", path);
 #endif
    HINSTANCE retcode;
    retcode = ShellExecute(NULL, "open", path, cmdargs, NULL, SW_SHOWNORMAL);
#ifdef STUB_DEBUG
    printf("Return: %i\n", (int)retcode);
#endif
  }

  return 0;
}
