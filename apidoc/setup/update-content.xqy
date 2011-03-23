xquery version "1.0-ml";

import module namespace api="http://marklogic.com/rundmc/api"
       at "../model/data-access.xqy";
import module namespace ml="http://developer.marklogic.com/site/internal"
       at "../../model/data-access.xqy";

declare namespace apidoc="http://marklogic.com/xdmp/apidoc";

declare variable $query := '
  declare namespace apidoc="http://marklogic.com/xdmp/apidoc";
  fn:collection()[apidoc:module]
';

declare variable $raw-docs := xdmp:eval($query, (), <options xmlns="xdmp:eval">
                                                      <database>{xdmp:database("docapp")}</database>
                                                    </options>);

declare variable $all-functions      := $raw-docs/*/apidoc:function;
declare variable $built-in-functions := $raw-docs/*/apidoc:function[    @type eq 'builtin'];
declare variable $library-functions  := $raw-docs/*/apidoc:function[not(@type eq 'builtin')];

declare variable $built-in-modules := distinct-values($built-in-functions/@lib);
declare variable $library-modules  := distinct-values($library-functions/@lib);

declare function local:make-list-page($functions, $descriptor, $are-namespace-specific) {

  document {
    (: Being careful to avoid the element name "api:function", which we've reserved already :)
    <api:function-list-page title-prefix="{$descriptor}" disable-comments="yes">{

      if ($are-namespace-specific) then
        let $prefix := $descriptor,
            $ns-uri := api:uri-for-prefix($prefix) return
         (attribute namespace { $ns-uri },
          attribute prefix    { $prefix }
         )
      else (),

      for $func in $functions order by $func/@fullname return
        <api:function-listing>
          <api:name>{fn:string($func/@fullname)}</api:name>
          <api:description>{
            (: Use the same code that docapp uses for extracting the summary (first line) :)
            fn:concat(fn:tokenize($func/apidoc:summary,"\.(\s+|\s*$)")[1], ".")
          }</api:description>
        </api:function-listing>

    }</api:function-list-page>
  }
};

 
"Inserting function docs and associated comment thread containers...",
for $doc in $raw-docs return 
  for $func in xdmp:xslt-invoke("extract-functions.xsl", $doc) return
  (
    xdmp:document-insert(fn:base-uri($func), $func),
    ml:insert-comment-doc(fn:base-uri($func))
  ),

"Inserting master list...",
xdmp:document-insert("/apidoc/index.xml", local:make-list-page($all-functions, "All", false())),

"Inserting list for each built-in module...",
for $m in $built-in-modules return
  xdmp:document-insert(fn:concat("/apidoc/", $m, ".xml"),
                       local:make-list-page($built-in-functions[@lib eq $m], $m, true())
                      ),

"Inserting list for each library module...",
for $m in $library-modules return
  (: Workaround for "spell" which includes both built-in and library functions :)
  let $path := if ($m eq 'spell') then 'spell-lib' else $m return
  xdmp:document-insert(fn:concat("/apidoc/", $path, ".xml"),
                       local:make-list-page($library-functions[@lib eq $m], $m, true())
                      ),

"Inserting built-in master list...",
xdmp:document-insert("/apidoc/built-in.xml", local:make-list-page($built-in-functions, "All built-in", false())),

"Inserting library master list...",
xdmp:document-insert("/apidoc/library.xml", local:make-list-page($library-functions, "All library", false())),

(: Run as a subsequent transaction, because it depends on the documents inserted above. :)
xdmp:invoke("update-toc.xqy")
