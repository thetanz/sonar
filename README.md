![](https://avatars0.githubusercontent.com/u/2897191?s=70&v=4)
# sonar

_thetanz/sonar_ was an ingestion framework for [Project Sonar](https://www.rapid7.com/research/project-sonar/), an initiative led by [Rapid7](https://www.rapid7.com) that provided normalised datasets of global network scan data across public internet space.

Intended for monthly execution, these scripts would concurrently download and process all available Rapid 7 datasets into Google Big Query with the help of multiple Google Compute instances.

---

## Deprecation Notice

**Rapid 7 have deprecated the public revision of this service, see the below post released `Feb 10, 2022`**

[Evolving How We Share Rapid7 Research Data](https://www.rapid7.com/blog/post/2022/02/10/evolving-how-we-share-rapid7-research-data-2/)

It would appear as though the case noted below coupled with [GDPR](https://gdpr.eu/what-is-gdpr/) & [CCPA](https://oag.ca.gov/privacy/ccpa) regulations have put into question what Rapid 7 can publicly share.

> Case [C-582/14](https://curia.europa.eu/juris/documents.jsf?num=C-582/14) - _The court ruled that [dynamic IP addresses](http://www.twobirds.com/en/news/articles/2016/netherlands/ag-s-opinion-on-dynamic-ip-addresses-may-shed-a-broader-light-on-the-definition-of-personal-data) may constitute ‘personal data’ even where only a third party (in this case an internet service provider) has the additional data necessary to identify the individual_
> - [CJEU Judgement - twobirds](https://www.twobirds.com/en/news/articles/2016/global/cjeu-decision-on-dynamic-ip-addresses-touches-fundamental-dp-law-questions)
> - [Court of Justice of the European Union Press Release](https://curia.europa.eu/jcms/upload/docs/application/pdf/2016-10/cp160112en.pdf)
> - [Art. 6 GDPR Lawfulness of processing](https://gdpr-info.eu/art-6-gdpr/)
> - [Recital 49 Network and Information Security as Overriding Legitimate Interest](https://gdpr-info.eu/recitals/no-49/)
> - [Can a dynamic IP address constitute personal data ? - fieldfisher Law](https://www.fieldfisher.com/en/services/privacy-security-and-information/privacy-security-and-information-law-blog/can-a-dynamic-ip-address-constitute-personal-data)

If you intend on using Rapid7's service for publicly-disclosed research it would appear as though [you can still gain access by reaching out.](https://twitter.com/Infosecjen/status/1491788584692576267)

> **This ingestion framework is being released in an archived state. No support or updates to follow**

---

## Overview

This set of scripts helps ingest monthly GZIP archives on scan datasets. Data is downloaded and subsequently loaded back into Google CLoud's Big Query service.

URL's from BackBlaze are fetched, subsequently downloading archived before processing and loading events

> these scripts expect the presence of a GCP service account JSON file within the current directory, named `gcp-svc-sonar.json`

The container image by default will iterate through each dataset listed within the [variable file](datasets.sh)

This can take a fair amount of time to download, process and load _(upwards of 15 hours)_ with many disk-heavy operations

The dockerfile will initially run the orchestrator script `orchestrator.sh` which will read the sourcetypes in the `sonardatasets` array within the variable file `datasets.sh`.

For every sourcetype identified the latest available URL to download the given dataset is discovered and is passed to `loader.sh`

The loader creates the relevant SQL table and downloads the sonar tarball. We treat downloads differently depending on BQ's [quotas](https://cloud.google.com/bigquery/quotas).

The files are simply too large to process in-memory so all datasets are currently written to disk and uploaded as either direct or indirect, chunked tarballs depending on the ultimate size of the archive.

> when the archive is over 4gb whilst still below 15tb we chunk the file into three-milion line sections and create tarballs for each

Tarballs are uploaded directly as [compressive uploads](https://cloud.google.com/storage/docs/transcoding) with content-encoding values.

Once the tarball is available in JSON form within GCP Storage, a [BQ Batch Load Operation](https://cloud.google.com/bigquery/docs/batch-loading-data) brings this in with indexing leveraging inline [decompressive transcoding](https://cloud.google.com/storage/docs/transcoding).
## Schemas

Big Query can 'auto detect' a json schema but it can be temperamental. Establishing a fixed schema is the best way to ensure reliable ingestion and removed any auto-detection guesswork.

Whilst Rapid 7 provide a standard schema, Big Query requires a custom file to specify this . Reference the [Google docs on BQ Schemas](https://cloud.google.com/bigquery/docs/schemas#creating_a_json_schema_file) for more info

_the schema provided by rapid7 can be fetched with the below_

```shell
baseuri='https://opendata.rapid7.com'
schemafile=`curl -s ${baseuri}/sonar.rdns_v2/ | grep "schema.json" | cut -d '"' -f2`
wget --no-verbose --show-progress --progress=dot:mega ${baseuri}${schemafile} -O json_schema.json
```

## Running

### GCP Parallel

**time:** 4-6 hours

create a set of gcp container vm's to process each dataset concurrently with [`batch.sh`](batch.sh).

> when using `batch.sh` - ensure you update `YOUR_GCP_PROJECT` accordingly to allow google container registry to correctly function within the context of your project

### Local Singleton

**time:** 30-40 hours 
**free disk space:** ~200gb

```shell
docker build . -t sonar
docker run sonar
```

> you can specify a single dataset from the [variable file](datasets.sh) as an input argument to process an individual dataset, i.e

```shell
docker run sonar fdns_v2:fdns_txt_mx_dmarc.json.gz
```

## Notes

- piping a gzip archive to gcp big query directly takes longer than it does to upload it with transcoding to gcp storage and running a subsequent load job 

- we implicitly decompress and chunk any archive over 4gb - we can upload decompressed archives up to 15tb in size however we save on data transfer costs when we only upload tarballs/archives.

- the decompressed archives _(80gb+ json line-delimited files)_ are massive, chunking at any good speed is rather difficult - we avoid doing so wherever possible.

- using GNU's `chunk` doesn't seem to do 'in place' chunking so we end up downloading an archive, unpacking it & then chunking it which doubles disk space. some of these large datasets can often grow above 80GB after decompression.

- maintaining direct pipes from stdin would be ideal but the sheer filesize of some operations makes this difficult given compute and memory availability
    ```shell
    wget example.com/file.gz | unzip | upload
    ```
- due to the inherent size of these datasets work with tools such as `sed/awk` take extended amounts of time  - no transposing/additions to datasets is performed

---