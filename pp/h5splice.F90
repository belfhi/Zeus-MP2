!-----------------------------------------------------------------------
!
!                            Developed by
!                Laboratory of Computational Astrophysics
!                 University of California at San Diego
!
subroutine h5splice
#ifdef USE_HDF5
!
! ZEUS-MP Post-processor: H5SPLICE.
!
! PURPOSE:  This program reads all HDF5 DUMPS from a ZEUS-MP run
!           and assembles them into a single huge file which looks
!           like one from a single-processor job with the same
!           physical mesh.
!
! Written:  By John Hayes, May 2006
!
!.......................................................................
!
      use real_prec
      use config
      use param
      use mpino
      use mpipar
      use grid
      use root
!
      use hdf5
!
      implicit NONE
!
!-----------------------------------------------------------------------
!     hdf5-specific parameters, identifiers, etc.
!-----------------------------------------------------------------------
!
      integer        :: rank, error
      integer(hid_t) :: tfile_id             ! tile file IDs
      integer(hid_t) :: cfile_id             ! combined file ID
      integer(hsize_t), dimension(7) :: dims
!
      character*7    :: ax_label(0:3), scr_ch, scr_1
      character*11, dimension(:), allocatable :: dsetname 
!
!-----------------------------------------------------------------------
!     zmp_inp namelists/parameters
!-----------------------------------------------------------------------
!
!      integer   :: irestart
!
      real(rl) :: x1min,x1max,x1rat,dx1min,dfndx1r,x1r,deltx1r,errx1r, &
                  x2min,x2max,x2rat,dx2min,dfndx2r,x2r,deltx2r,errx2r, &
                  x3min,x3max,x3rat,dx3min,dfndx3r,x3r,deltx3r,errx3r
!
      integer   :: nbl,igrid,imin,imax,jmin,jmax,kmin,kmax
      logical   :: lgrid
!
      namelist /geomconf/  lgeom, ldimen
      namelist /physconf/  lrad   , xhydro , xgrav, xmhd    , xgrvfft, &
                           xptmass, xtotnrg, xiso , xvgrid  , xsubav, &
                           xforce , xsphgrv, leos , nspec, xchem
      namelist /ioconf/    xascii , xhdf, xrestart, xtsl, xhst
      namelist /preconf/   small_no, large_no
      namelist /arrayconf/ izones, jzones, kzones, maxijk
      namelist /rescon/ irestart,tdump,dtdump,id,resfile
      namelist /mpitop/ ntiles, periodic
      namelist /ggen1/  nbl,x1min,x1max,igrid,x1rat,dx1min,lgrid
      namelist /ggen2/  nbl,x2min,x2max,igrid,x2rat,dx2min,lgrid
      namelist /ggen3/  nbl,x3min,x3max,igrid,x3rat,dx3min,lgrid
!
!-----------------------------------------------------------------------
!     file, function, array counters
!-----------------------------------------------------------------------
!
      integer   :: iskip,jskip,kskip,izone,jzone,kzone
      integer   :: n, indx, icmb, ndump, jcmb, kcmb
      integer   :: it,jt,kt,i,j,k,itil
      integer   :: nfunc,lfunc
!
!-----------------------------------------------------------------------
!     local/global data arrays
!-----------------------------------------------------------------------
!
      real(rl4)  :: tval
      real(rl4), dimension(:), allocatable :: xscale, yscale, zscale, &
                                              scr_in, scr_jn, scr_kn
!
      real(rl4), dimension(:), allocatable :: xscmb, yscmb, zscmb
      real(rl4), dimension(:    ), allocatable :: data
      real(rl4), dimension(:,:,:), allocatable :: dcmb
!
      integer, parameter :: max_pe = 512
      !integer, parameter :: max_fc = 513
!
!-----------------------------------------------------------------------
!     file names and misc.
!-----------------------------------------------------------------------
!
      character*8 phrase
      character*23 hdf(max_pe)
      character*16 cmb
      character*120 line
!
!=======================================================================
!     Read namelist data
!=======================================================================
!
!-----------------------------------------------------------------------
!     Read ZEUS-MP input file "zmp_inp" to determine the number of zones
!     in each direction in the physical mesh (nx1z,nx2z,nx3z), and the 
!     number of tiles in each direction "ntiles".
!-----------------------------------------------------------------------
!
      open(1,file='zmp_inp',status='old')
!
!-----------------------------------------------------------------------
!     read the code configuration namelists
!-----------------------------------------------------------------------
!
      read(1,geomconf)
      read(1,physconf)
      read(1,ioconf)
      read(1,preconf)
      read(1,arrayconf)
!
      in = izones + 5
      jn = jzones + 5
      kn = kzones + 5
!
!
!-----------------------------------------------------------------------
!   Look for and read the "mpitop" and "ggen*" namelists.
!-----------------------------------------------------------------------
!
!       do 10 n=1,100
!         read(1,"(a8)") phrase
!         if (phrase(3:8) .eq. 'mpitop' .or. &
!             phrase(3:8) .eq. 'MPITOP') goto 20
!   10  continue
!       write(*,"(/'H5SPLICE: ERROR -- Did not find mpitop namelist.')")
!       close (1)
!       return
!!
!   20  continue
!       backspace (1)
       read(1,mpitop)
       write(*,"('H5SPLICE: ntiles is ',3i6)") ntiles(1),ntiles(2) &
       , ntiles(3)
!
      allocate(data(izones* jzones* kzones))
!
      allocate(xscale(izones))
      allocate(scr_in(izones))
      allocate(yscale(jzones))
      allocate(scr_jn(jzones))
      allocate(zscale(kzones))
      allocate(scr_kn(kzones))
!
      allocate(xscmb(izones*ntiles(1)))
      allocate(yscmb(jzones*ntiles(2)))
      allocate(zscmb(kzones*ntiles(3)))

      allocate(dcmb (izones*ntiles(1), &
                     jzones*ntiles(2), &
                     kzones*ntiles(3)))
!
!-----------------------------------------------------------------------
!   Read the "rescon" namelist to find the run's "id".
!-----------------------------------------------------------------------
!
       irestart = 0
       tdump    = 0.0
       dtdump   = 0.0
       id       = 'aa'
       resfile  = 'resaa000000.0000'
       read (1,rescon)
       write(*,"(/'H5SPLICE: id is ',a)") id
!
       imax  = 3
       imin = imax
       nbl   = 1
       lgrid = .false.
!
   30  continue
       read(1,ggen1)
       imax = imax + nbl
       if (.not. lgrid) go to 30
!
       nx1z = ( imax - imin ) / ntiles(1)
!PS
!
       jmax  = 3
       jmin  = jmax
       nbl   = 1
       lgrid = .false.
!
   40  continue
       read(1,ggen2)
       jmax = jmax + nbl
       if (.not. lgrid) go to 40
!
       nx2z = ( jmax - jmin ) / ntiles(2)
!
!
       kmax  = 3
       kmin = kmax
       nbl   = 1
       lgrid = .false.
!
   50  continue
       read(1,ggen3)
       kmax = kmax + nbl
       if (.not. lgrid) go to 40
!
       nx3z = ( kmax - kmin ) / ntiles(3)
!PS
!
       write(*,"('H5SPLICE: nx1z,nx2z,nx3z are ',3i6)") nx1z,nx2z,nx3z
       close(1)
       write(*,"('H5SPLICE: i,j,k-zones are:' 3i6)") izones, jzones, kzones
!
      nfunc = 5
      if(xmhd) nfunc = nfunc + 3
#ifdef VORTEX
      nfunc = nfunc + 1 ! including dump of div(v)
#endif
      if(lrad .ne. 0) nfunc = nfunc + 1
!
      allocate(dsetname(nfunc))
!
      dsetname(1) = "i_velocity"
      dsetname(2) = "j_velocity"
      dsetname(3) = "k_velocity"
      if(xmhd) then
       dsetname(4) = "i_mag_field"
       dsetname(5) = "j_mag_field"
       dsetname(6) = "k_mag_field"
       dsetname(7) = "Density"
       dsetname(8) = "GasEnergy"
       if(lrad .gt. 0) dsetname(9) = "rad_energy"
      else
       dsetname(4) = "Density"
       dsetname(5) = "GasEnergy"
       if(lrad .gt. 0) dsetname(6) = "rad_energy"
      endif
!
!
!=======================================================================
!     Initialize FORTRAN interface.
!=======================================================================
!
      CALL h5open_f (error)
!
!=======================================================================
!     Main loop over output dump number
!=======================================================================
!
!-----------------------------------------------------------------------
!     Ask for the dump number.  Loop back to this point when finished
!     with this dump number.  Negative input dump number terminates
!     execution.
!-----------------------------------------------------------------------
!
60    CONTINUE
!
      write(*,"(/'H5SPLICE: Enter desired dump number; <0 quits:'/)")
      read(*,*) ndump
      if (ndump .lt. 0) then
        return
      endif
!
!-----------------------------------------------------------------------
!     Generate names of hdf files to read.
!-----------------------------------------------------------------------
!
!  Added DD000x directory
       indx = 0
       do 90 kt=0,ntiles(3)-1
         do 80 jt=0,ntiles(2)-1
           do 70 it=0,ntiles(1)-1
             indx = indx + 1
             write(hdf(indx),"(a2,i4.4,a1,a3,a2,3i2.2,'.',i4.4)") 'DD',ndump,'/', 'hdf',id &
             , it,jt,kt,ndump
   70      continue
   80    continue
   90  continue
       nprocs = indx
!
!-----------------------------------------------------------------------
!     Read each function from each tile's dump and write it into
!     the combined file 'cmb' ("hdf<id>.<ndump>").
!-----------------------------------------------------------------------
!
      write(cmb,"(a3,a2,'.',i3.3)") 'hdf',id,ndump
!
      CALL h5fcreate_f(cmb, H5F_ACC_TRUNC_F, cfile_id, error)
!
!=======================================================================
!     Begin loop over data arrays (coords, velocities, rho, etc.)
!=======================================================================
!
      DO LFUNC = 1, NFUNC  ! NFUNC counts only the 3-D data arrays.
!
!-----------------------------------------------------------------------
!     Begin loop over tile files
!-----------------------------------------------------------------------
!
       indx = 0
       DO KT = 0,ntiles(3)-1
        DO JT = 0,ntiles(2)-1
         DO IT = 0,ntiles(1)-1
!
          indx = indx + 1
          call h5fopen_f(hdf(indx),h5f_acc_rdonly_f,tfile_id,error)
!
!-----------------------------------------------------------------------
!         for lfunc = 1, also read coordinate arrays and save.  when
!         lfunc > 1, read arrays but discard.
!-----------------------------------------------------------------------
!
          RANK      = 1
          dims(1  ) = 1
          dims(2:7) = 0
          if(lfunc .eq. 1 .and. indx .eq. 1) then
           call read_viz(tfile_id,rank,dims,"time",tval)
          else
           call read_viz(tfile_id,rank,dims,"time",scr_1)
          endif
!
!
          dims(1  ) = izones
          if(lfunc .eq. 1) then
           call read_viz(tfile_id,rank,dims,"i_coord",xscale)
           do i = 1, nx1z
            xscmb(i+it*nx1z) = xscale(i)
           enddo
          else
           call read_viz(tfile_id,rank,dims,"i_coord",scr_in)
          endif
!
          dims(1  ) = jzones
          if(lfunc .eq. 1) then
           call read_viz(tfile_id,rank,dims,"j_coord",yscale)
           do j = 1, nx2z
            yscmb(j+jt*nx2z) = yscale(j)
           enddo
          else
           call read_viz(tfile_id,rank,dims,"j_coord",scr_jn)
          endif
!
          dims(1  ) = kzones
          if(lfunc .eq. 1) then
           call read_viz(tfile_id,rank,dims,"k_coord",zscale)
           do k = 1, nx3z
            zscmb(k+kt*nx3z) = zscale(k)
           enddo
          else
           call read_viz(tfile_id,rank,dims,"k_coord",scr_kn)
          endif
!
!
          RANK      = 3
          dims(1  ) = izones
          dims(2  ) = jzones
          dims(3  ) = kzones
          dims(4:7) = 0
          call read_viz(tfile_id,rank,dims,dsetname(lfunc),data)
!
          do k=1,nx3z
           do j=1,nx2z
            do i=1,nx1z
             itil = i + (j-1)*nx1z + (k-1)*nx1z*nx2z
             !itil = i*j*k
!             icmb       = i + it*nx1z  &
!                            + (j+jt*nx2z-1)*(ntiles(1)*nx1z) &
!                            + (k+kt*nx3z-1)*(ntiles(1)*nx1z) &
!                            * (ntiles(2)*nx2z)
             icmb                 = i + it*nx1z 
             jcmb                 = j + jt*nx2z
             kcmb                 = k + kt*nx3z
             dcmb(icmb,jcmb,kcmb) = data(itil)
            enddo ! i
           enddo ! j
          enddo ! k
          !write(*,*) shape(dcmb)
! 
!-----------------------------------------------------------------------
!     Terminate access to the tile file.
!-----------------------------------------------------------------------
!
          CALL h5fclose_f(tfile_id, error)
!
         ENDDO ! IT
        ENDDO ! JT
       ENDDO ! KT
!
       if(lfunc .eq. 1) then
        RANK = 1
        dims(1  ) = 1
        dims(2:7) = 0
        call write_cmb(cfile_id,rank,dims,"time",tval)
!
        dims(1  ) = izones*ntiles(1)
        dims(2:7) = 0
        call write_cmb(cfile_id,rank,dims,"i_coord",xscmb)
!
        dims(1  ) = jzones*ntiles(2)
        dims(2:7) = 0
        call write_cmb(cfile_id,rank,dims,"j_coord",yscmb)
!
        dims(1  ) = kzones*ntiles(3)
        dims(2:7) = 0
        call write_cmb(cfile_id,rank,dims,"k_coord",zscmb)
       endif ! lfunc
!
       RANK = 3
       dims(1  ) = izones*ntiles(1)
       dims(2  ) = jzones*ntiles(2)
       dims(3  ) = kzones*ntiles(3)
       dims(4:7) = 0
       call write_cmb(cfile_id,rank,dims,dsetname(lfunc),dcmb)
!
      ENDDO ! LFUNC
!
!-----------------------------------------------------------------------
!     Terminate access to the combined data file.
!-----------------------------------------------------------------------
!
      CALL h5fclose_f(cfile_id, error)
!
!=======================================================================
!     Loop back up for the next dump.
!=======================================================================
!
       GOTO 60
!
!=======================================================================
!     Error messages
!=======================================================================
!
  999  continue
       write(*,"(/'H5SPLICE: ERROR -- could not open file ',a16 &
       , ' for tile ',i4)") hdf(indx),indx
!
       return
       end
!=======================================================================
!=======================================================================
      subroutine read_viz(file_id,rank,dims,dsetname,dset)
!
      use hdf5
!
      implicit none
!
      integer(hid_t) :: file_id                ! file identifier
      integer ::   rank                        ! dataset rank
      integer(hsize_t), dimension(7) :: dims   ! dataset dimensions
      character(len=*) :: dsetname             ! dataset name
      real(kind=4) :: dset
!
!
      integer(hid_t) :: dset_id       ! dataset identifier
      integer(hid_t) :: dspace_id     ! dataspace identifier
      integer :: error
!
      call h5screate_simple_f(rank, dims, dspace_id, error)
!                      ! Get dset_id for data set
      call h5dopen_f(file_id,dsetname,dset_id,error)
!
      call h5dread_f(dset_id, h5t_native_real, dset, dims, error)
      call h5dclose_f(dset_id, error) ! end access to the dataset
      call h5sclose_f(dspace_id, error) ! term. access to data space
!
      return
      end
!=======================================================================
!=======================================================================
      subroutine write_cmb(file_id,rank,dims,dsetname,dset)
!
      use hdf5
!
      implicit none
!
      integer(hid_t) :: file_id                ! file identifier
      integer ::   rank                        ! dataset rank
      integer(hsize_t), dimension(7) :: dims   ! dataset dimensions
      character(len=*) :: dsetname             ! dataset name
      real(kind=4) :: dset
!
!
      integer(hid_t) :: dset_id       ! dataset identifier
      integer(hid_t) :: dspace_id     ! dataspace identifier
      integer :: error
!
      call h5screate_simple_f(rank, dims, dspace_id, error)
!
!                      ! Get dset_id for data set
      call h5dcreate_f(file_id,dsetname,h5t_native_real,dspace_id, &
                       dset_id,error)
!
      call h5dwrite_f(dset_id, h5t_native_real, dset, dims, error)
      call h5dclose_f(dset_id, error) ! end access to the dataset
      call h5sclose_f(dspace_id, error) ! term. access to data space
!
#endif /* USE_HDF5 */
      return
end subroutine
