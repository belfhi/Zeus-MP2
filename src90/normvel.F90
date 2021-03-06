      subroutine normvel(rms)
!--------------------------------------------------------------------!
!
!    normalizes volocity - field to v_rms = rms
!
!--------------------------------------------------------------------!
      use real_prec
      use field
      use grid
      use param
#ifdef MPI_USED
      use mpiyes
#else
      use mpino
#endif
      use mpipar
      implicit NONE
      real(rl) :: norm, rms, av
      integer  :: i, j, k, ip, jp, kp
      norm = 0.0
      do k=ks, ke
        kp = k+1
        do j=js, je
          jp = j+1
          do i=is, ie
            ip = i+1
            norm = norm + &
                   (v1(i,j,k)+v1(ip,j ,k ))**2. + &
                   (v2(i,j,k)+v2(i ,jp,k ))**2. + &
                   (v3(i,j,k)+v3(i ,j ,kp))**2.
          enddo ! i
        enddo ! j
      enddo ! k
      norm = sqrt(norm*0.25/real(ijkn)**3/rms**2.)
      v1 = v1/norm
      v2 = v2/norm
      v3 = v3/norm
      av  = 0.0
      rms = 0.0
      do k=ks, ke
        kp = k+1
        do j=js, je
          jp = j+1
          do i=is, ie
            ip = i+1
            av  = av  + ( v1(i,j,k) + v1(ip,j ,k ) &
                      +   v2(i,j,k) + v2(i ,jp,k ) &
                      +   v3(i,j,k) + v3(i, j ,kp) )*0.5
            rms = rms + ((v1(i,j,k) + v1(ip,j ,k ))**2 &
                      +  (v2(i,j,k) + v2(i ,jp,k ))**2 &
                      +  (v3(i,j,k) + v3(i ,j ,kp))**2)*0.25
          enddo
        enddo
      enddo
      av  = av/(3.0*real(ijkn)**3)
      rms = sqrt(rms/(real(ijkn)**3))
#ifdef MPI_USED
      if (myid_w .eq. 0) then
        write(6,*)'NORMVEL  :'
        write(6,*)'NORMVEL  : Norm     = ',norm
        write(6,*)'NORMVEL  : V_av     = ',av
        write(6,*)'NORMVEL  : V_rms    = ',rms
        write(6,*)'NORMVEL  :'
      endif
#endif /* MPI_USED */
      return
      end                 
