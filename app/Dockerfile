FROM golang:1.24 AS builder

WORKDIR /app

COPY . .

RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux go build -o fileserver .

FROM alpine:3.20

RUN adduser -D appuser

USER appuser

COPY --from=builder /app/fileserver /fileserver

EXPOSE 8080

ENTRYPOINT ["/fileserver"]
