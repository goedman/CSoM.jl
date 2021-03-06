#!/usr/bin/env julia

using WriteVTK
using Test
import Compat: UTF8String, readstring
using SHA: sha1

const tests = ["multiblock.jl",
               "rectilinear.jl",
               "imagedata.jl",
               "structured.jl",
               "unstructured.jl",
               "pvdCollection.jl",
               "array.jl"]

# Only toggle to generate new checksums, if new tests are added.
const OVERWRITE_CHECKSUMS = true
const checksums_file = joinpath(dirname(@__FILE__), "checksums.sha1")
const checksum_list = read(checksums_file, String)

if OVERWRITE_CHECKSUMS
    csio = open(checksums_file, "w")
end

ProjDir = dirname(@__FILE__)
cd(ProjDir*"/output") do
  
  # Run the test scripts.
  for test in tests
      println("TEST (first run): ", test)
      outfiles = evalfile(test)::Vector{UTF8String}

      # Check that the generated files match the stored checksums.
      for file in outfiles
          sha_str = bytes2hex(open(sha1, file)) * "  $file\n"
          if OVERWRITE_CHECKSUMS
              write(csio, sha_str)
          else
              # Returns 0:-1 if string is not found.
              cmp = search(checksum_list, sha_str)
              @test cmp != 0:-1
          end
      end
      println()
  end

  OVERWRITE_CHECKSUMS && close(csio)

  println("="^60, "\n")

  # Run the tests again, just to measure the time and allocations once all the
  # functions have already been compiled.
  for test in tests
      println("TEST (second run): ", test)
      outfiles = evalfile(test)::Vector{UTF8String}
      println()
  end

end