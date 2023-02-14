# Building

To build container:
```
docker build -t sgb-blog .
```

To run container at localhost:8001:
```
docker run -p 8001:8000 \
  --mount "type=bind,source=$(pwd)/src,target=/code/src" \
  -it sgb-blog
```
