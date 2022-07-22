

process pipits_create_pairsline {
    tag ""

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
    tag ""

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
    tag ""

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'yumyai/pipits:2.8--pyhdfd78af_0' :
        'yumyai/pipits:2.8--pyhdfd78af_0' }"

    // Need to be collect in one batch
    input:
    path readpairslist
    file reads // Collected read

    output:
    path 'out_seqprep/output.log'       , emit: outlog
    path 'out_seqprep/prepped.fasta'       , emit: fasta
    path 'out_seqprep/summary.log'       , emit: sumlog
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


workflow PIPITS {

  take:
    input_ch
  main:
    pipits_create_pairsline (
      input_ch.out.reads // Has meta data in read too, name misleading a bit.
    )
    // pipits_create_pairsline.out.view()
    pipits_create_pairslist(
      pipits_create_pairsline.out.line.collect()
    )

    reads_chn = input_ch.out.reads.flatMap {
          reads -> [ reads[1][0], reads[1][1]]
    }.flatten().collect()


    pipits_seq_prep(
      pipits_create_pairslist.out.readpairslist,
      reads_chn
    )

  //emit:
  //  pipits_seq_prep.out.fasta
}
