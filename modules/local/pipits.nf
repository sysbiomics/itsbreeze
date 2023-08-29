

process pipits_create_pairsline {
    label 'process_low'

    // Need to be collect in one batch
    input:
    tuple val(meta), path(reads)

    output:
    val line, emit: line

    script:
    line = [meta.id, reads[0].toString(), reads[1].toString()].join("\t")
    """
    """
}

process pipits_create_pairslist {
    label "process_low"

    // Need to be collect in one batch
    input:
    val lines

    output:
    path "readpairslist.txt", emit: readpairslist

    script:
    txt = lines.join(System.getProperty("line.separator"))
    """
    echo "${txt}" >> readpairslist.txt
    """
}

process pipits_seq_prep {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::pipits==2.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'yumyai/pipits:2.8--pyhdfd78af_0' :
        'yumyai/pipits:2.8--pyhdfd78af_0' }"

    // Need to be collect in one batch
    input:
    path readpairslist
    path reads // Collected read

    output:
    path 'out_seqprep/output.log'       , emit: outlog
    path 'out_seqprep/prepped.fasta'    , emit: preppedfasta
    path 'out_seqprep/summary.log'      , emit: sumlog
    path "versions.yml", emit: versions

    script:
    """
    pispino_seqprep -i . -o out_seqprep -l ${readpairslist}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}

process pipits_funits {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::pipits==2.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'yumyai/pipits:2.8--pyhdfd78af_0' :
        'yumyai/pipits:2.8--pyhdfd78af_0' }"

    // Need to be collect in one batch
    input:
    path preppedfasta
    val ITS // Either ITS1 or ITS2

    output:
    path 'out_funits/ITS.fasta'      , emit: itsfasta
    path 'out_funits/output.log'     , emit: outlog
    path 'out_funits/summary.log'    , emit: sumlog
    path "versions.yml", emit: versions

    script:
    """
      pipits_funits -i ${preppedfasta} -o out_funits -x ${ITS} -v -r -t ${task.process}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        which pipits_process | xargs cat | head -n10
    END_VERSIONS

    """
}

process pipits_process {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::pipits==2.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'yumyai/pipits:2.8--pyhdfd78af_0' :
        'yumyai/pipits:2.8--pyhdfd78af_0' }"

    // Need to be collect in one batch
    input:
    path ITSfasta

    output:
    path 'out_process/otu_table.txt',                              emit: otutable
    path 'out_process/assigned_taxonomy_reformatted_filtered.txt', emit: taxtable
    path "versions.yml",                                           emit: versions

    script:
    """
      pipits_process -i ${ITSfasta} -o out_process -v -r -t ${task.process}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        which pipits_process | xargs cat | head -n10
    END_VERSIONS
    """
}


workflow PIPITS {

  take:
    reads
  main:
    pipits_create_pairsline (
      reads // Has meta data in read too, name misleading a bit.
    )
    // pipits_create_pairsline.out.view()
    pipits_create_pairslist(
      pipits_create_pairsline.out.line.collect()
    )

    reads_chn = reads.flatMap {
          reads -> [ reads[1][0], reads[1][1]]
    }.flatten().collect()


    pipits_seq_prep(
      pipits_create_pairslist.out.readpairslist,
      reads_chn
    )

    pipits_funits(
      pipits_seq_prep.out.preppedfasta,
      "ITS2"
    )

    pipits_process(
      pipits_funits.out.itsfasta
    )

  emit:
    otutable = pipits_process.out.otutable
    taxtable = pipits_process.out.taxtable
    versions = pipits_process.out.versions
}
