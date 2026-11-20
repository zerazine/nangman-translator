#!/bin/sh
R=/usr/lib/mono/4.5-api
cd "$(dirname "$0")" && mcs -nostdlib -noconfig -target:winexe -win32icon:app.ico -codepage:utf8 \
 -r:$R/mscorlib.dll -r:$R/System.dll -r:$R/System.Core.dll -r:$R/System.Windows.Forms.dll -r:$R/System.Drawing.dll -r:$R/System.Web.Extensions.dll \
 -out:setup.exe Setup.cs
