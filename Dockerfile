# Production-ready Dockerfile for cloud deployment
FROM drupal:10-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    nodejs \
    npm \
    unzip \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Composer dependencies for Drupal modules
RUN composer require \
    drupal/feeds \
    drupal/views_data_export \
    drush/drush:^12

# Create application directories
RUN mkdir -p /var/www/html/database \
    /var/www/html/data

# Embed SQLite settings directly in container
RUN echo '<?php\n\
$databases["default"]["default"] = [\n\
  "database" => "/var/www/html/database/portfolio.sqlite",\n\
  "prefix" => "",\n\
  "namespace" => "Drupal\\\\Core\\\\Database\\\\Driver\\\\sqlite",\n\
  "driver" => "sqlite",\n\
];\n\
\n\
$settings["hash_salt"] = getenv("DRUPAL_HASH_SALT") ?: "default-dev-salt";\n\
$settings["update_free_access"] = FALSE;\n\
\n\
if (getenv("DRUPAL_ENV") === "production") {\n\
  $config["system.performance"]["css"]["preprocess"] = TRUE;\n\
  $config["system.performance"]["js"]["preprocess"] = TRUE;\n\
  $config["system.performance"]["cache"]["page"]["max_age"] = 3600;\n\
}\n' > /var/www/html/sites/default/settings.local.php

# Copy application files
COPY themes/ /var/www/html/themes/custom/
COPY data/ /var/www/html/data/
COPY database/ /var/www/html/database/
COPY files/ /var/www/html/sites/default/files/

# Build theme assets
WORKDIR /var/www/html/themes/custom/portfolio
RUN npm install && npm run build

# Set proper permissions
RUN chown -R www-data:www-data \
    /var/www/html/database \
    /var/www/html/sites/default/files \
    /var/www/html/themes/custom \
    && chmod -R 755 /var/www/html/sites/default/files \
    && chmod 664 /var/www/html/database/*.sqlite 2>/dev/null || true

# Embed initialization script directly
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting Drupal initialization..."\n\
\n\
if [ ! -f /var/www/html/database/portfolio.sqlite ] || [ ! -f /var/www/html/database/.initialized ]; then\n\
    echo "Initializing fresh Drupal installation..."\n\
    drush site:install standard \\\n\
        --db-url=sqlite://database/portfolio.sqlite \\\n\
        --site-name="${DRUPAL_SITE_NAME:-Portfolio}" \\\n\
        --account-name="${DRUPAL_ADMIN_USER:-admin}" \\\n\
        --account-pass="${DRUPAL_ADMIN_PASS:-admin}" \\\n\
        --yes\n\
    \n\
    drush en feeds views_data_export -y\n\
    \n\
    if [ -d /var/www/html/themes/custom/portfolio ]; then\n\
        drush theme:enable portfolio\n\
        drush config:set system.theme default portfolio -y\n\
    fi\n\
    \n\
    touch /var/www/html/database/.initialized\n\
    echo "Drupal initialization complete!"\n\
fi\n\
\n\
drush cache:rebuild\n\
exec apache2-foreground' > /usr/local/bin/init.sh \
    && chmod +x /usr/local/bin/init.sh

# Switch back to web root
WORKDIR /var/www/html

# Health check for cloud deployment
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose port
EXPOSE 80

# Use initialization script
CMD ["/usr/local/bin/init.sh"]