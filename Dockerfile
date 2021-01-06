FROM alpine

ENV DAEMON_MODE=enabled \
    CONTAINER_MODE=enabled

COPY ./get_stats.sh /

RUN apk add --no-cache jq && \
    apk add --no-cache curl && \
    apk add --no-cache bash && \
    chmod +x /get_stats.sh

CMD ["/get_stats.sh", "-a"]
