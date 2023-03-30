# Rate Limiting with the Fastly Edge
Enjoy the examples. Feedback is welcome.

# Pre-reqs
* Make sure Edge Rate Limiting is enabled for your Fastly Account. [About Edge Rate Limiting](https://docs.fastly.com/en/guides/about-edge-rate-limiting)

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
## Rate Limit by all distinct URL
If there is a hard limit on the amount of traffic your backend should receive, then you may enforce a rate counter for distinct URLs. This includes query params as well.
## Rate Limit by groupings of URLs
If there is a hard limit on the amount of traffic your backend should receive for groupings of endpoints, then you may enforce a rate counter for those groupings as well. Grouping URLs can be helpful when the same backends are used for many different web or API endpoints.

## Put requests in the ERL Penalty Box when a specific condition is met from the origin response
The origin can have access to different sources of intelligence and data. If a block action is take at the origin, then the block can tell the edge that future requests should be blocked based on a condition such as the client IP.

# How to test
There are a spectrum of different tools out there to test out the rate limiting functionality. [Siege](https://github.com/JoeDog/siege) is one of my favorite because of how simple it is.

`siege https://YOUR_DOMAIN_HERE/some/path/123?x-obj-status=206`

Other tools like [vegeta](https://github.com/tsenart/vegeta) are highly customizable and highly performant tools.

`echo "GET https://YOUR_DOMAIN_HERE/some/path/123?x-obj-status=206" | vegeta attack -header "vegeta-test:ratelimittest1" -duration=60s  | vegeta report -type=text`
