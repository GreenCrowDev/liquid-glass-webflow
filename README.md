## Libraries

- [liquidGL](https://github.com/naughtyduk/liquidGL)

## Guide

```
docker pull node:24-slim

docker run -it --rm --entrypoint sh node:24-slim
```

```
docker run -it --rm ^
  -v "D:\repos\work\liquid-glass-webflow:/app" ^
  -w /app ^
  --entrypoint sh node:24-slim
```

Use this, otherwise you won't be able to see the website on your machine port 3000:

```
docker run -it --rm ^
  -p 3000:3000 ^
  -v "D:\repos\work\liquid-glass-webflow:/app" ^
  -w /app ^
  node:24-slim sh
```

Make sure that the package.json has:

```
"dev": "vite --host 0.0.0.0 --port 3000",
```

Then in the terminal connected to the docker VM:

```
npm install
npm run dev
```