# Rate Limiting with the Fastly Edge
This repository contains functional examples to use Fastly Edge Rate Limiting product. For more information, see the Fastly documentation [About Edge Rate Limiting](https://docs.fastly.com/en/guides/about-edge-rate-limiting).

# Pre-reqs
* Make sure Edge Rate Limiting is enabled for your Fastly Account. 

# How to deploy
* Customize the USER_DOMAIN_NAME variable in variables.tf
* `terraform apply`
* Use your favorite tool to validate the functionality.
* Need to restart? Just run `terraform destroy` and start over.

# What Edge Rate Limiting examples are in here?
## Default ERL configuration
This is the out of the box configuration for ERL all within a single init VCL snippet

## Rate Limit by ASN when the request is coming from a hosting provider
Hosting providers can often be the source for abusive traffic since it is economically more attractive for attackers to use hosting provider proxies for sourcing attacks. This snippet will only check the rate for requests that are sourced from hosting providers. If the rate is exceeded, then the ASN name will be the key for rate limiting.

## Rate limit by user id in a request header
Many applications, especially APIs, will utilize a specific header for distinguishing between users. This example uses the request header "user-id" as the rate limiting identifier.

## Rate Limit by all distinct URL
If there is a hard limit on the amount of traffic your backend should receive, then you may enforce a rate counter for distinct URLs. This includes query params as well.

## Rate Limit by groupings of URLs
If there is a hard limit on the amount of traffic your backend should receive for groupings of endpoints, then you may enforce a rate counter for those groupings as well. Grouping URLs can be helpful when the same backends are used for many different web or API endpoints.

## Put requests in the ERL Penalty Box when a specific condition is met from the origin response
The origin can have access to different sources of intelligence and data. If a block action is take at the origin, then the block can tell the edge that future requests should be blocked based on a condition such as the client IP.

## Rate Limit on lower volume traffic
Many misuse and abuse cases are generated from lower volume traffic volumes. A common problem is credential stuffing or credential cracking on a login form. A frequent way to add friction for an attacker is to block an client by IP address, request header, or some other identifier after an excessive number of login attempts. This example uses the request header *rl-key* as the client identifier entry. The snippet named _edge_rate_limiting_low_volume.vcl_ utilizes the [60 second ratecounter bucket](https://developer.fastly.com/reference/vcl/variables/rate-limiting/ratecounter-bucket-60s/) as the value to determine if a request is in violation of the configured allowed rate of requests. The way to configure the request per 60 seconds (aka request per minute or RPM) rate is with the edge dictionary named _login_paths_. You can then see the headers in a response to inspect the decision making. 
* rl-rate-60 
* rl-bucket-60
* rl-delta

Information on these header values can be in the snippet _debug_low_volume_edge_rate_limit.vcl_. In a production setting, you would not want to reflect these values back to an attacker. It is possible to also use the _delta_ parameter with the check_rate VCL function to increment high risk traffic. In this example snippet, you may add the request header *high-risk* with any value to see the concept in action. This type of logic could be useful when you want high risk traffic to hit the upper bound on rate more quickly, such as traffic coming from ToR or other sources with a significant amount of abusive traffic.


# How to test
There are a spectrum of different tools out there to test out the rate limiting functionality. [Siege](https://github.com/JoeDog/siege) is one of my favorite because of how simple it is.

`siege https://YOUR_DOMAIN_HERE/some/path/123?x-obj-status=206`

Other tools like [vegeta](https://github.com/tsenart/vegeta) are highly customizable and highly performant tools.

`echo "GET https://YOUR_DOMAIN_HERE/some/path/123?x-obj-status=206" | vegeta attack -header "vegeta-test:ratelimittest1" -duration=60s  | vegeta report -type=text`

Also, there should be a helpful output for testing after successfully running `terraform apply`.
