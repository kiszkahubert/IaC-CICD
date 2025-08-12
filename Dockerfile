FROM node:18-alpine
WORKDIR /app
COPY application/package.json application/package-lock.json* ./
RUN npm ci && npm audit fix --force
COPY application/ .
EXPOSE 3000
CMD ["npm", "start"]
