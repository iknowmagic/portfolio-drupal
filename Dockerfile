FROM drupal:10-apache

# Install mysql client and build tools
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Copy and build your theme
COPY themes/portfolio /var/www/html/themes/custom/portfolio
WORKDIR /var/www/html/themes/custom/portfolio
RUN npm install && npm run build

# Copy uploaded files
COPY files/ /var/www/html/sites/default/files/

# Set permissions
RUN chown -R www-data:www-data /var/www/html/sites/default/files
RUN chown -R www-data:www-data /var/www/html/themes/custom

EXPOSE 80
CMD ["apache2-foreground"]