while getopts e: flag
do
    case "${flag}" in
        e) executor=${OPTARG};;
		p) profile=${OPTARG};;
    esac
done

nextflow run main.nf -profile test,conda --outdir outconda -process.executor=$executor
nextflow run main.nf -profile test,singularity --outdir outsingu -process.executor=$executor
