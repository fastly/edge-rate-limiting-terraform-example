# vcl_deliver

if(fastly.ff.visits_this_service == 0 && req.http.fastly-debug){

    set resp.http.rl-check-rate = req.http.rl-check-rate;
    set resp.http.rl-hit = req.http.Fastly-SEC-RateLimit;
    set resp.http.rl-rate-60 = ratecounter.rl_low_volume_rc.rate.60s;
    /* set resp.http.client-ip = req.http.fastly-client-ip; */
    set resp.http.rl-bucket-60 = ratecounter.rl_low_volume_rc.bucket.60s;
    set resp.http.rl-delta = req.http.rl-low-volume-delta;
}

# remove request headers if the request is already cached so as to not log headers