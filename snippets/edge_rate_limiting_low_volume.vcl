
# Snippet rate-limiter-v1-low_volume-init
penaltybox rl_low_volume_pb {}
ratecounter rl_low_volume_rc {}
table rl_low_volume_methods {
  "GET": "true",
  "PUT": "true",
  "TRACE": "true",
  "POST": "true",
  "HEAD": "true",
  "DELETE": "true",
  "PATCH": "true",
  "OPTIONS": "true",
}

# use a seperate table for the ERL tuning

sub rl_low_volume_process {
  declare local var.rl_low_volume_window INTEGER;
  declare local var.rl_low_volume_limit INTEGER;
  declare local var.rl_low_volume_ttl TIME;
  declare local var.rl_low_volume_entry STRING;
  declare local var.rl_low_volume_delta INTEGER;
  declare local var.rl_low_volume_60_sec_bucket_limit INTEGER;

  set var.rl_low_volume_window = 60;
  set var.rl_low_volume_limit = 10;

  if (std.atoi(table.lookup(login_edge_rate_limit_config, "rate_limit_delta_value")) > 0) {
    set var.rl_low_volume_delta = std.atoi(table.lookup(login_edge_rate_limit_config, "rate_limit_delta_value"));
  } else {
    set var.rl_low_volume_delta = 60;
  }
  set req.http.rl-low-volume-delta = var.rl_low_volume_delta;

  # ERL's check_rate requires an integer greater than 9
  if (std.atoi(table.lookup(login_edge_rate_limit_config, "rate_limit_rpm_value")) > 1) {
    set var.rl_low_volume_60_sec_bucket_limit = std.atoi(table.lookup(login_edge_rate_limit_config, "rate_limit_rpm_value"));
  } else {
    set var.rl_low_volume_60_sec_bucket_limit = 10;
  }

  # 10 is the lowest value that may be used for the check_rate function, but the approximate aggregate counts for a window are available in the rate counter buckets.
  # https://developer.fastly.com/reference/vcl/variables/rate-limiting/

  set var.rl_low_volume_ttl = 2m;
  /* set var.rl_low_volume_entry = client.ip; */
  set var.rl_low_volume_entry = req.http.rl-key;
  if (req.restarts == 0 && fastly.ff.visits_this_service == 0
      && table.contains(rl_low_volume_methods, req.method)
      && table.contains(login_paths, std.tolower(req.url.path))
      && std.strlen(var.rl_low_volume_entry) > 0
      && table.lookup(login_edge_rate_limit_config, "blocking") == "true"
      ) {
    # set req.http.rl-check-rate = "true"; # use for debugging
    if (req.http.high-risk) {
      if (ratelimit.check_rate(var.rl_low_volume_entry
        , rl_low_volume_rc
        , 3 # Using higher delta value for higher risk requests
        , var.rl_low_volume_window
        , var.rl_low_volume_limit
        , rl_low_volume_pb
        , var.rl_low_volume_ttl)
        ) {
      # set req.http.Fastly-SEC-RateLimit = "true"; # use for debugging
      set req.http.Fastly-login-erl-limit = table.lookup(login_edge_rate_limit_config, "login_edge_rate_limit_config");
      error 829 "Rate limiter: Too many requests for low_volume";
    } 
    }
    if (ratelimit.check_rate(var.rl_low_volume_entry
        , rl_low_volume_rc
        , var.rl_low_volume_delta
        , var.rl_low_volume_window
        , var.rl_low_volume_limit
        , rl_low_volume_pb
        , var.rl_low_volume_ttl)
        ) {
      /* set req.http.Fastly-SEC-RateLimit = "true"; # Use for debugging */
      set req.http.Fastly-login-erl-limit = table.lookup(login_edge_rate_limit_config, "login_edge_rate_limit_config");
      error 829 "Rate limiter: Too many requests for low_volume";
    } 
    if (ratecounter.rl_low_volume_rc.bucket.60s > var.rl_low_volume_60_sec_bucket_limit) {
      /* set req.http.Fastly-SEC-RateLimit = "true"; # Use for debugging */
      set req.http.Fastly-login-erl-limit = table.lookup(login_edge_rate_limit_config, "login_edge_rate_limit_config");
      error 829 "Rate limiter: Too many requests for low_volume";
    }
  }
}

sub vcl_miss {
    # Snippet rate-limiter-v1-low_volume-miss
    call rl_low_volume_process;
}

sub vcl_pass {
    # Snippet rate-limiter-v1-low_volume-pass
    call rl_low_volume_process;
}

sub vcl_error {
    # Snippet rate-limiter-v1-low_volume-error
    if (obj.status == 829 && obj.response == "Rate limiter: Too many requests for low_volume") {
        set obj.status = 429;
        set obj.response = "Too Many Requests";
        set obj.http.Content-Type = "text/html";
        synthetic.base64 "PGh0bWw+Cgk8aGVhZD4KCQk8dGl0bGU+VG9vIE1hbnkgUmVxdWVzdHM8L3RpdGxlPgoJPC9oZWFkPgoJPGJvZHk+CgkJPHA+VG9vIE1hbnkgUmVxdWVzdHMgdG8gdGhlIHNpdGU8L3A+Cgk8L2JvZHk+CjwvaHRtbD4=";
        return(deliver);
    }
}