FROM node:18-alpine
WORKDIR /app
COPY application/package.json application/package-lock.json* ./
RUN npm install
COPY application/ .
EXPOSE 3000
CMD ["npm", "start"]
