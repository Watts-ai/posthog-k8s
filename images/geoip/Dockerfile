FROM alpine:3.20 AS download
RUN apk add --no-cache curl brotli
RUN curl -L "https://mmdbcdn.posthog.net/" --http1.1 --fail --retry 5 | brotli --decompress > /GeoLite2-City.mmdb

FROM busybox:1.36
COPY --from=download /GeoLite2-City.mmdb /GeoLite2-City.mmdb
# Default: copy the bundled database to /share
CMD ["cp", "/GeoLite2-City.mmdb", "/share/GeoLite2-City.mmdb"]
