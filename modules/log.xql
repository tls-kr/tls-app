xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0

Based on code by Adam Retter on the exist slack channel

:)
module namespace log="http://hxwd.org/log";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "lib/permissions.xqm"; 

(:~
 : TRACE log level.
 :)
declare variable $log:TRACE as xs:integer := 1;

(:~
 : DEBUG log level.
 :)
declare variable $log:DEBUG as xs:integer := 2;

(:~
 : INFO log level.
 :)
declare variable $log:INFO as xs:integer := 3;

(:~
 : WARN log level.
 :)
declare variable $log:WARN as xs:integer := 4;

(:~
 : ERROR log level.
 :)
declare variable $log:ERROR as xs:integer := 5;


(:~
 : XPath Error code for when an invalid log level is used.
 :)
declare variable $log:ERROR_INVALID_LEVEL := xs:QName("log:ERROR_INVALID_LEVEL");

(:~
 : Write a log entry at TRACE level.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $message the message to write to the log entry.
 :)
declare function log:trace($log-collection as xs:string, $message as xs:string) as empty-sequence() {
  log:message($log-collection, $log:TRACE, $message)
};

(:~
 : Write a log entry at DEBUG level.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $message the message to write to the log entry.
 :)
declare function log:debug($log-collection as xs:string, $message as xs:string) as empty-sequence() {
  log:message($log-collection, $log:DEBUG, $message)
};

(:~
 : Write a log entry at INFO level.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $message the message to write to the log entry.
 :)
declare function log:info($log-collection as xs:string, $message as xs:string) as empty-sequence() {
  log:message($log-collection, $log:INFO, $message)
};

(:~
 : Write a log entry at WARN level.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $message the message to write to the log entry.
 :)
declare function log:warn($log-collection as xs:string, $message as xs:string) as empty-sequence() {
  log:message($log-collection, $log:WARN, $message)
};

(:~
 : Write a log entry at ERROR level.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $message the message to write to the log entry.
 :)
declare function log:error($log-collection as xs:string, $message as xs:string) as empty-sequence() {
  log:message($log-collection, $log:ERROR, $message)
};

(:~
 : Write a log entry.
 :
 : @param $log-collection the collection to hold the log entry.
 : @param $level the log level for the log entry.
 : @param $message the message to write to the log entry.
 :
 : @error log:ERROR_INVALID_LEVEL if an invalid level is requested.
 :)
declare function log:message($log-collection as xs:string, $level as xs:integer, $message as xs:string) as empty-sequence() {
  if (lpm:can-write-debug-log()) then 
  let $status-string := log:get-level-string($level)
  let $timestamp := util:system-dateTime()
  let $log-file-path := log:get-or-create-log-file($log-collection, $timestamp)
  let $log := fn:doc($log-file-path)/log
  return
    update insert <entry level="{$status-string}" timestamp="{$timestamp}">{$message}</entry> into $log
  else ()
};

(:~
 : Get the log level as a string.
 :
 : @param $level the log level.
 :
 : @return a string representation of the log level.
 :
 : @error log:ERROR_INVALID_LEVEL if an invalid level is requested.
 :)
declare
  (: %private :) (: NOTE(AR) commented out to make testable with XQSuite :)
function log:get-level-string($level as xs:integer) as xs:string {
  switch ($level)
    case $log:TRACE return "trace"
    case $log:DEBUG return "debug"
    case $log:INFO return "info"
    case $log:WARN return "warn"
    case $log:ERROR return "error"
    default return fn:error($log:ERROR_INVALID_LEVEL, "Unknown level: " || $level)
};

(:~
 : Get or create a log file.
 :
 : @param $log-collection the collection to hold the log file.
 : @param $timestamp the timestamp for the log file.
 :
 : @return the path to the log file.
 :)
declare
  (: %private :) (: NOTE(AR) commented out to make testable with XQSuite :)
function log:get-or-create-log-file($log-collection as xs:string, $timestamp as xs:dateTime) as xs:string {

  (: Create log collection if it does not exist :)
  let $_ :=
      if (not(xmldb:collection-available($log-collection)))
      then
         dbu:ensure-collection($log-collection)
      else()

  (: NOTE(AR) the TimeZone here will be whatever timezone the query is executed in... more specifically it is the timezone of the host system :)
  let $log-file-name := "log." || fn:format-dateTime($timestamp, "[Y0001]-[M01]-[D01]") || ".xml"
  let $log-file-path := $log-collection || "/" || $log-file-name
  return
    if (fn:doc-available($log-file-path))
    then
      $log-file-path
    else
      log:create-log-file($log-collection, $log-file-name, $timestamp)
};

(:~
 : Create a log file.
 :
 : @param $log-collection the collection to hold the log file.
 : @param $log-file-name the name of the log file.
 : @param $timestamp the timestamp for the log file.
 :
 : @return the path to the log file.
 :)
declare
  (: %private :) (: NOTE(AR) commented out to make testable with XQSuite :)
function log:create-log-file($log-collection as xs:string, $log-file-name as xs:string, $timestamp as xs:dateTime) as xs:string {
  let $empty-log-file := <log date="{$timestamp cast as xs:date}"/>
  return
    xmldb:store($log-collection, $log-file-name, $empty-log-file)
};