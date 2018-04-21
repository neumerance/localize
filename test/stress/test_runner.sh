#!/bin/bash
echo "Migrating...."
Rails.env=test rake db:drop db:create db:migrate > /dev/null

echo "Running..."
Rails.env=test $(pwd)/../../script/runner $*
