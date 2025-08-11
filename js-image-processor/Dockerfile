# Use the same Node.js version as your Lambda runtime
FROM node:18-slim

# Set a working directory inside the container
WORKDIR /app

# Copy the package files from the current directory
COPY package*.json ./

# Run npm install inside the Linux container. This will fetch the correct
# linux-x64 binaries for sharp automatically.
RUN npm install

# Copy the rest of your JavaScript source code from the current directory
COPY . ./

# The container is now ready, holding the correctly built artifacts.
CMD ["echo", "Build artifacts are ready in /app"]