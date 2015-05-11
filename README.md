Contentful-Exporter 
=================

## Description

This allows you to export structured JSON data from
[Contentful](https://www.contentful.com).  You can then use
[contentful-importer](https://github.com/contentful/contentful-importer.rb) to
import the data into another space.

## Installation

```bash
gem install contentful-exporter
```

This will install the ```contentful-exporter``` executable.

## Usage

Before you can export your content from Contentful, you need to create a
`settings.yml` file and fill in your credentials:

```yaml
#Contentful
access_token: access_token
space_id: organization_id
```

**A Contentful OAuth access token can be created using the [Contentful Management API - documentation](https://www.contentful.com/developers/documentation/content-management-api/#getting-started)**

Once you installed the Gem and created the YAML file with the settings you can invoke the tool using:

```bash
contentful-exporter --config-file settings.yml --action
```

## Step by step

1. Create YAML file with required parameters (eg. ```settings.yml```):

    ```yaml
    #PATH to all data
    data_dir: DEFINE_BEFORE_EXPORTING_DATA

    #Contentful credentials
    access_token: ACCESS_TOKEN
    space_id: SPACE_ID
    ```

1. Now your content can be exported. It can be chosen to use one (default) or
   two parallel threads to speedup this process.

    **Entries**

    ```bash
    contentful-exporter --config-file settings.yml --export-entries
    ```

    or

    ```bash
    contentful-exporter --config-file settings.yml --export --threads 2
    ```

    **Assets**

    ```bash
    contentful-exporter --config-file settings.yml --export-assets
    ```

    or

    **Content-types**

    ```bash
    contentful-exporter --config-file settings.yml --export-content-types
    ```

    or

    **All**

    ```bash
    contentful-exporter --config-file settings.yml --export
    ```

## Actions

To display all actions use the `-h` option:

```bash
contentful-exporter -h
```

#### --test-credentials

Before exporting any content you can verify that your credentials in the **settings.yml** file are correct:

```bash
contentful-exporter --config-file settings.yml --test-credentials
```
