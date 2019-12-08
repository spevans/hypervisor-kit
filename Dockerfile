# Run using: docker build --tag=hypervisorkit-tests:$(date +%s) .
FROM swift:5.1.2

COPY . /root/
WORKDIR /root
RUN swift test -v
