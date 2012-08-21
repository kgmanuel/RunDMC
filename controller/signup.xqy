xquery version "1.0-ml";

import module namespace json="http://marklogic.com/json" at "/lib/mljson/lib/json.xqy";
import module namespace path="http://marklogic.com/mljson/path-parser" at "/lib/mljson/lib/path-parser.xqy";
import module namespace users="users" at "/lib/users.xqy";
import module namespace util="http://markmail.org/util" at "/lib/util.xqy";


let $signed_request := xdmp:get-request-field("signed_request")

return if (not(exists($signed_request))) then

    (: sign up directly :)
    let $email := xdmp:get-request-field("s_email")
    let $password := xdmp:get-request-field("s_password")
    let $confirm-password := xdmp:get-request-field("s_password_confirm")
    let $name := xdmp:get-request-field("s_name")
    let $signup := xdmp:get-request-field("list", "off")

    (: validate email addy, passwords, etc :)
    let $valid := util:validateEmail($email) and 
        (fn:string-length($email) le 255) and
        (fn:string-length($password) le 255) and
        ($password and not($password eq "")) and 
        ($password eq $confirm-password) and 
        ($name and not($name eq "")) and
        true()
    
    (: rely on nice client side error messages; this validation is for protection, so no need to be nice with error text :)
    let $user := if ($valid) then users:createOrUpdateUser($name, $email, $password, $signup)
        else "invalid form input"

    return if ($user instance of element()) then
        let $_ := xdmp:set-response-content-type("text/html")
        let $_ := users:startSession($user)
        return <html><script type="text/javascript"><![CDATA[
               window.location = "/products";
        ]]></script></html>
    
    else
        xdmp:redirect-response(concat("/people/signup?e=", $user))

else

    (: sign up via facebook :)

    let $data := users:validateFacebookSignedRequest($signed_request)

    return

        if (not(exists($data))) then
            let $url := xdmp:url-encode("/people/signup?e=Your request appears to have been tampered with.", false())

            return xdmp:redirect-response($url)
            
        else
            let $json := json:parse($data)
            let $name := path:select($json, "registration.name", "json")/string()
            let $email := path:select($json, "registration.email", "json")/string()
            let $password := path:select($json, "registration.password", "json")/string()
            let $signup := path:select($json, "registration.list", "json")/string()
            let $fb-id := path:select($json, "user_id", "json")/string() 
            let $pic := concat("https://graph.facebook.com/", $fb-id, "/picture") 
            
            let $user := users:createOrUpdateFacebookUser($name, $email, $password, $fb-id, $signup)

            return if ($user instance of element()) then
                let $_ := users:startSession($user)
                let $_ := xdmp:set-response-content-type("text/html")
                return 
                        <html><script type="text/javascript"><![CDATA[
                            window.location = "/products";
                        ]]></script></html>
            else
                xdmp:redirect-response(concat("/people/signup?e=", $user))