FROM node:latest
WORKDIR /app
COPY application/package.json application/package-lock.json* ./
RUN npm ci && npm install cross-spawn@7.0.5 --save-exact && npm dedupe
COPY application/ .
EXPOSE 3000
CMD ["npm", "start"]
