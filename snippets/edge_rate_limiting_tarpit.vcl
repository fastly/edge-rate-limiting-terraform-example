
# Snippet rate-limiter-v1-green_gandolf-init
penaltybox rl_blue_sherlock_pb {}
ratecounter rl_blue_sherlock_rc {}
table rl_blue_sherlock_methods {
  "GET": "true",
  "PUT": "true",
  "TRACE": "true",
  "POST": "true",
  "HEAD": "true",
  "DELETE": "true",
  "PATCH": "true",
  "OPTIONS": "true",
}
sub rl_blue_sherlock_process {
  declare local var.rl_blue_sherlock_limit INTEGER;
  declare local var.rl_blue_sherlock_window INTEGER;
  declare local var.rl_blue_sherlock_ttl TIME;
  declare local var.rl_blue_sherlock_entry STRING;
  set var.rl_blue_sherlock_limit = 10;
  set var.rl_blue_sherlock_window = 60;
  set var.rl_blue_sherlock_ttl = 5m;
  // set var.rl_blue_sherlock_entry = client.ip;
  set var.rl_blue_sherlock_entry = req.http.tarpit;
  if (req.restarts == 0 && fastly.ff.visits_this_service == 0
      && table.contains(rl_blue_sherlock_methods, req.method)
      && std.strlen(req.http.tarpit) > 0
      ) {
    if (ratelimit.check_rate(var.rl_blue_sherlock_entry
        , rl_blue_sherlock_rc, 1
        , var.rl_blue_sherlock_window
        , var.rl_blue_sherlock_limit
        , rl_blue_sherlock_pb
        , var.rl_blue_sherlock_ttl)
        || std.strlen(req.http.slowdown) > 0 // using the slowdown header for testing the tarpitting behavior.
        ) {
        
      
      // Set a request header which may be used to in vcl_deliver to check if the response should be tarpitted
      set req.http.Fastly-SEC-Tarpit = "true";
      // error 829 "Rate limiter: Too many requests for blue sherlock";
    }
  }
}

sub vcl_miss {
    # Snippet rate-limiter-v1-green_gandolf-miss
    call rl_blue_sherlock_process;
}

sub vcl_pass {
    # Snippet rate-limiter-v1-green_gandolf-pass
    call rl_blue_sherlock_process;
}

sub vcl_deliver {  
  if (req.http.Fastly-SEC-Tarpit == "true"){
    set resp.http.fastly-tarpitted = "true";
    resp.tarpit(1, 100);
  }
}

sub vcl_error {
    # Snippet rate-limiter-v1-green_gandolf-error
    if (obj.status == 829 && obj.response == "Rate limiter: Too many requests for green_gandolf") {
        set obj.status = 429;
        set obj.response = "Too Many Requests";
        set obj.http.Content-Type = "text/html";
        synthetic.base64 "PGh0bWw+Cgk8aGVhZD4KCQk8dGl0bGU+VG9vIE1hbnkgUmVxdWVzdHM8L3RpdGxlPgoJPC9oZWFkPgoJPGJvZHk+CgkJPHA+VG9vIE1hbnkgUmVxdWVzdHMgdG8gdGhlIHNpdGU8L3A+Cgk8L2JvZHk+CjwvaHRtbD4=";
        return(deliver);
    }
}