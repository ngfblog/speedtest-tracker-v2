FROM henrywhitaker3/speedtest-tracker

# Install Node.js for building
RUN apk add --no-cache nodejs npm 2>/dev/null || \
    apt-get update && apt-get install -y nodejs npm 2>/dev/null || \
    true

WORKDIR /site

# Copy fixed JS source files (DD/MM/YY date format)
COPY src/HistoryGraph.js /site/resources/js/components/Graphics/HistoryGraph.js
COPY src/TableRow.js /site/resources/js/components/Graphics/TableRow.js

# Build the JS bundle
RUN npm install && npm run production

# Copy fixed PHP controller ($days passed correctly to actions)
COPY src/HomepageDataController.php /site/app/Http/Controllers/HomepageDataController.php
