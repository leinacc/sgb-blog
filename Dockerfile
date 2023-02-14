# Get a python 3.10 image
FROM python:3.10.9
SHELL ["bash", "-lc"]
RUN apt update
RUN apt install curl -y

# Install rust and mdbook
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN apt install gcc -y
RUN source "$HOME/.cargo/env"
RUN cargo install mdbook

COPY . /code
WORKDIR /code

# Serve pandocs at localhost:8000
RUN mdbook build
CMD (cd /code/ && mdbook watch) & (cd /code/book/ && python3 -m http.server)
