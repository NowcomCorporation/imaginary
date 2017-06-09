#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and https://www.varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

import directors;

backend node1 {
    .host = "10.172.12.5";
    .port = "9000";
    .probe = {
        .request = "GET /health HTTP/1.1"
                   "Host: 10.172.12.5"
                   "Connection: Close"
                   "Accept-Encoding: text/html";
        .interval = 1s;
        .timeout = 500 ms;
        .window = 5;
        .threshold = 3;
    }
}

backend node2 {
    .host = "10.172.12.6";
    .port = "9000";
    .probe = {
        .request = "GET /health HTTP/1.1"
                   "Host: 10.172.12.6"
                   "Connection: Close"
                   "Accept-Encoding: text/html";
        .interval = 1s;
        .timeout = 500 ms;
        .window = 5;
        .threshold = 3;
    }
}


sub vcl_init {
    new wp_director = directors.round_robin();
    wp_director.add_backend(node1);
    wp_director.add_backend(node2);
}

sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.

    # Drop any cookies sent to Wordpress

    if (req.method == "PURGE") {
        if (req.http.X-Host-To-Purge == "ALL") {
            ban("req.http.host ~ .");
            return (synth(200, "Banned content from all hosts."));
        } else {
            ban("req.http.host == " + req.http.X-Host-To-Purge);
            return (synth(200, "Banned content from host: [" + req.http.X-Host-To-Purge + "]"));
        }
    }
    unset req.http.cookie;
    set req.backend_hint = wp_director.backend();
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # Drop any cookies Wordpress tries to send back to the client

    if (beresp.ttl <= 0s ||
        beresp.http.Set-Cookie ||
        beresp.http.Surrogate-Control ~ "no-store" ||
        (!beresp.http.Surrogate-Control && beresp.http.Cache-Control ~ "no-cache|no-store|private") ||
        beresp.http.Vary == "*") {
        /*
         * Mark as "Hit-For-Pass" for the next 2 minutes
         */
        set beresp.ttl = 2m;
        set beresp.uncacheable = true;
        return (deliver);
    }

    set beresp.ttl = 12h;
    return (deliver);
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
}

sub vcl_synth {
    set resp.http.Content-Type = "text/html; charset=utf-8";
    set resp.http.Retry-After = "5";
    synthetic( {"<!DOCTYPE html>
<html>
  <head>
    <title>"} + resp.status + " " + resp.reason + {"</title>
  </head>
  <body>
    <h1>"} + resp.status + " " + resp.reason + {"</h1>
    <p>"} + resp.reason + {"</p>
    <p>XID: "} + req.xid + {"</p>
    <hr>
  </body>
</html>
"} );
    return (deliver);
}
