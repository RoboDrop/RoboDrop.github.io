#!/bin/bash
POST_DATE=$(date +"%Y-%m-%d")
POST_TITLE=$1
POST_SLUG=$(echo $POST_TITLE | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
POST_DIR="_posts"
ASSET_DIR="assets/images/posts/${POST_DATE}-${POST_SLUG}"

# Create post file
POST_FILE="${POST_DIR}/${POST_DATE}-${POST_SLUG}.md"
echo "---" > $POST_FILE
echo "layout: post" >> $POST_FILE
echo "title: \"$POST_TITLE\"" >> $POST_FILE
echo "date: $POST_DATE" >> $POST_FILE
echo "featured_image: /$ASSET_DIR/featured.png" >> $POST_FILE
echo "---" >> $POST_FILE
echo "Content goes here." >> $POST_FILE

# Create asset folder
mkdir -p $ASSET_DIR
touch $ASSET_DIR/featured.png

echo "Post created: $POST_FILE"
echo "Assets folder created: $ASSET_DIR"
