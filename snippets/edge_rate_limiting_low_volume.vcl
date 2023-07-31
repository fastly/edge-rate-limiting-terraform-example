
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
  /* declare local var.rl_low_volume_window INTEGER; */
  declare local var.rl_low_volume_limit INTEGER;
  declare local var.rl_low_volume_entry STRING;
  declare local var.rl_low_volume_delta INTEGER;
  declare local var.rl_low_volume_60_sec_bucket_limit INTEGER;

  # Check if the entry is greater than 0
  /* if (table.lookup(login_edge_rate_limit_config, "rl_low_volume_60_sec_bucket_limit") > 0) { */
  if (std.atoi(table.lookup(login_edge_rate_limit_config, "rl_low_volume_60_sec_bucket_limit")) > 0) {
    set var.rl_low_volume_60_sec_bucket_limit = std.atoi(table.lookup(login_edge_rate_limit_config, "rl_low_volume_60_sec_bucket_limit"));
  } else {
    set var.rl_low_volume_60_sec_bucket_limit = 10 ;
  }

  set req.http.rl-limit = var.rl_low_volume_60_sec_bucket_limit;

  # Set for debugging
  set req.http.rl-low-volume-delta = var.rl_low_volume_delta;

  set var.rl_low_volume_entry = req.http.rl-key;
  if (req.restarts == 0 && fastly.ff.visits_this_service == 0
      && table.contains(rl_low_volume_methods, req.method)
      && table.contains(login_paths, std.tolower(req.url.path))
      && std.strlen(var.rl_low_volume_entry) > 0
      ) {

    # https://developer.fastly.com/reference/vcl/functions/rate-limiting/ratelimit-ratecounter-increment/
    # high risk
    declare local var.rl_last_60_sec_bucket INTEGER;
    if (req.http.high-risk || client.geo.proxy_description ~ "^tor-")  {
      set var.rl_last_60_sec_bucket = ratelimit.ratecounter_increment(rl_low_volume_rc, var.rl_low_volume_entry, 3);
    } else {
      # not high risk
      set var.rl_last_60_sec_bucket = ratelimit.ratecounter_increment(rl_low_volume_rc, var.rl_low_volume_entry, 1);
    }
   
    if (ratecounter.rl_low_volume_rc.bucket.60s > var.rl_low_volume_60_sec_bucket_limit
      && table.lookup(login_edge_rate_limit_config, "blocking") == "true") {
      /* set req.http.Fastly-SEC-RateLimit = "true"; # Use for debugging */
      /* set req.http.Fastly-erl-60-sec-bucket = ratecounter.rl_low_volume_rc.bucket.60s;  */
      /* set req.http.Fastly-login-erl-limit = table.lookup(login_edge_rate_limit_config, "login_edge_rate_limit_config"); */
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

#### Debug Rate limit with lower volume traffic - ONLY USE FOR DEBUGGING SINCE THIS SENDS RATE COUNT INFORMATION BACK TO THE CLIENT
sub vcl_deliver {
  if(fastly.ff.visits_this_service == 0 && req.http.fastly-debug){
    set resp.http.rl-limit = req.http.rl-limit;
    set resp.http.rl-bucket-60 = ratecounter.rl_low_volume_rc.bucket.60s;
    set resp.http.rl-delta = req.http.rl-low-volume-delta;
  }  
}

sub vcl_error {
    # Snippet rate-limiter-v1-low_volume-error
    if (obj.status == 829 && obj.response == "Rate limiter: Too many requests for low_volume") {
        set obj.status = 429;
        set obj.response = "Too Many Requests";
        set obj.http.Content-Type = "text/html";
        synthetic.base64 "PGh0bWw+CiAgICAgICAgPGhlYWQ+CiAgICAgICAgICAgICAgICA8dGl0bGU+VG9vIE1hbnkgUmVxdWVzdHM8L3RpdGxlPgogICAgICAgIDwvaGVhZD4KICAgICAgICA8Ym9keT4KICAgICAgICAgICAgICAgIDxwPlRvbyBNYW55IFJlcXVlc3RzIHRvIHRoZSBzaXRlLiBMViBFUkw8L3A+CiAgICAgICAgPC9ib2R5Pgo8L2h0bWw+";
        return(deliver);
    }
}