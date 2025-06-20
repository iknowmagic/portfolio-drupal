# Use the same base image as your local development
FROM drupal:10-apache

# Install required packages for production
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    nodejs \
    npm \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Drush globally
RUN composer global require drush/drush:^12 \
    && ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush

# Copy your custom theme
COPY themes/portfolio /var/www/html/themes/custom/portfolio

# Build CSS from your theme's build process
WORKDIR /var/www/html/themes/custom/portfolio
RUN npm install && npm run build

# Copy uploaded files (if they exist)
COPY files/ /var/www/html/sites/default/files/ 2>/dev/null || echo "No files directory found"

# Copy database dump for initialization (optional)
COPY database/ /var/www/html/database/ 2>/dev/null || echo "No database directory found"

# Set proper permissions for Drupal
RUN chown -R www-data:www-data /var/www/html/sites/default/files \
    && chown -R www-data:www-data /var/www/html/themes/custom \
    && chmod -R 755 /var/www/html/sites/default/files

# Create settings directory if it doesn't exist
RUN mkdir -p /var/www/html/sites/default \
    && chown -R www-data:www-data /var/www/html/sites/default

# Copy startup script
COPY scripts/start.sh /usr/local/bin/start.sh 2>/dev/null || echo "#!/bin/bash\napache2-foreground" > /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Back to web root
WORKDIR /var/www/html

# Expose port 80
EXPOSE 80

# Start Apache
CMD ["/usr/local/bin/start.sh"]