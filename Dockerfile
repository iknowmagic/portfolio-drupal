# Dockerfile
FROM drupal:10

# Install Drush
RUN composer require drush/drush
# Install additional Drupal modules
RUN composer require drupal/feeds
RUN composer require drupal/admin_toolbar

# Optional: Add Drush to PATH for convenience
ENV PATH="${PATH}:/opt/drupal/vendor/bin"