#!/bin/sh
# Wraps game.html (the page source) into a standalone index.html.
{ printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n</head>\n<body style="margin:0">\n'; cat game.html; printf '</body>\n</html>\n'; } > index.html
