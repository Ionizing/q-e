!
!---------------------------------------------------------------
      subroutine vxcgc(ndm,mesh,nspin,r,r2,rho,rhoc,vgc,egc)
!---------------------------------------------------------------
!
!
!     This routine compute the exchange and correlation potential and
!     energy to be added to the local density, to have the first
!     gradient correction.
!     In input the density is rho(r) (multiplied by 4*pi*r2).
!
!     The units of the potential are Ryd.
!

      implicit none
      integer, parameter :: dp=kind(1.d0)
      integer :: ndm,mesh,nspin,ndm1
      real(kind=dp) :: r(mesh), r2(mesh), rho(ndm,2), rhoc(ndm), &
             vgc(ndm,2), egc(ndm)

      integer :: i, is, ierr
      real(kind=dp) :: sx,sc,v1x,v2x,v1c,v2c,aux,gaux
      real(kind=dp) :: v1xup, v1xdw, v2xup, v2xdw, v1cup, v1cdw
      real(kind=dp) :: segno, arho, grho2(2)
      real(kind=dp) :: rh, zeta, grh2
      real(kind=dp),parameter :: eps=1.d-12, fourpi=3.14159265358979d0*4.d0

      real(kind=dp), pointer :: grho(:,:), h(:,:), dh(:)
!
!      First compute the charge and the charge gradient, assumed  
!      to have spherical symmetry. The gradient is the derivative of
!      the charge with respect to the modulus of r. The last point is
!      assumed to have zero gradient as happens in an atom.
!
      allocate(grho(mesh,2),stat=ierr)
      allocate(h(mesh,2),stat=ierr)
      allocate(dh(mesh),stat=ierr)

      egc=0.d0
      vgc=0.d0

      do is=1,nspin
         do i=1, mesh
            rho(i,is)=(rho(i,is)+rhoc(i)/nspin)/fourpi/r2(i)
         enddo
         do i=2, mesh-1
            grho(i,is)=( (r(i+1)-r(i))**2*(rho(i-1,is)-rho(i,is)) &
                    -(r(i-1)-r(i))**2*(rho(i+1,is)-rho(i,is)) )   &
                    /((r(i+1)-r(i))*(r(i-1)-r(i))*(r(i+1)-r(i-1)))
         enddo
         grho(mesh,is)=0.d0
!     
!     The gradient in the first point is a linear interpolation of the
!     gradient at point 2 and 3. The final result is not really sensitive to
!     the value of these derivatives.
!     
         grho(1,is)=grho(2,is)+(grho(3,is)-grho(2,is)) &
                                    *(r(1)-r(2))/(r(3)-r(2))
      enddo

      if (nspin.eq.1) then
!
!     GGA case
!
         do i=1,mesh
            arho=abs(rho(i,1)) 
            segno=sign(1.d0,rho(i,1))
            if (arho.gt.eps.and.abs(grho(i,1)).gt.eps) then
               call gcxc(arho,grho(i,1)**2,sx,sc,v1x,v2x,v1c,v2c)
               egc(i)=(sx+sc)*segno
               vgc(i,1)= v1x+v1c
               h(i,1)  =(v2x+v2c)*grho(i,1)*r2(i)
!            if (i.lt.4) write(6,'(f20.12,e20.12,2f20.12)') &
!                          rho(i,1), grho(i,1)**2,  &
!                          vgc(i,1),h(i,1)
            else if (i.gt.mesh/2) then
!
! these are asymptotic formulae (large r) 
!
               vgc(i,1)=-1.d0/r2(i)
               egc(i)=-0.d0/(2.d0*r(i))
               h(i,1)=h(i-1,1)
            else
               vgc(i,1)=0.d0
               egc(i)=0.d0
               h(i,1)=0.d0
            endif
         end do
      else
!
!   this is the \sigma-GGA case
!       
         do i=1,mesh
!
!  NB: the special or wrong cases where one or two charges 
!      or gradients are zero or negative must
!      be detected within the gcxc_spin routine
!
!            call gcxc_spin(rho(i,1),rho(i,2),grho(i,1),grho(i,2),  &
!                           sx,sc,v1xup,v1xdw,v2xup,v2xdw,          &
!                           v1cup,v1cdw,v2c)
        !
        !    spin-polarised case
        !
             do is = 1, nspin
                grho2(is)=grho(i,is)**2
             enddo
         
             call gcx_spin (rho(i, 1), rho(i, 2), grho2(1), grho2(2), &
                            sx, v1xup, v1xdw, v2xup, v2xdw)
             rh = rho(i, 1) + rho(i, 2)
             if (rh.gt.eps) then
                zeta = (rho (i, 1) - rho (i, 2) ) / rh
                grh2 = (grho (i, 1) + grho (i, 2) ) **2 
                call gcc_spin (rh, zeta, grh2, sc, v1cup, v1cdw, v2c)
             else
                sc = 0.d0
                v1cup = 0.d0
                v1cdw = 0.d0
                v2c = 0.d0
             endif

             egc(i)=sx+sc
             vgc(i,1)= v1xup+v1cup
             vgc(i,2)= v1xdw+v1cdw
             h(i,1)  =((v2xup+v2c)*grho(i,1)+v2c*grho(i,2))*r2(i)
             h(i,2)  =((v2xdw+v2c)*grho(i,2)+v2c*grho(i,1))*r2(i)
!            if (i.lt.4) write(6,'(f20.12,e20.12,2f20.12)') &
!                          rho(i,1)*2.d0, grho(i,1)**2*4.d0, &
!                          vgc(i,1),  h(i,2)
         enddo
      endif
!     
!     We need the gradient of h to calculate the last part of the exchange
!     and correlation potential.
!     
      do is=1,nspin
         do i=2,mesh-1
            dh(i)=( (r(i+1)-r(i))**2*(h(i-1,is)-h(i,is))  &
                    -(r(i-1)-r(i))**2*(h(i+1,is)-h(i,is)) ) &
                  /( (r(i+1)-r(i))*(r(i-1)-r(i))*(r(i+1)-r(i-1)) )
         enddo

         dh(1)=dh(2)+(dh(3)-dh(2)) &
                          *(r(1)-r(2))/(r(3)-r(2))
         dh(mesh)=0.d0
!
!     Finally we compute the total exchange and correlation energy and
!     potential. We put the original values on the charge and multiply
!     by two to have as output Ry units.

         do i=1, mesh
            vgc(i,is)=vgc(i,is)-dh(i)/r2(i)
            rho(i,is)=rho(i,is)*fourpi*r2(i)-rhoc(i)/nspin
            vgc(i,is)=2.d0*vgc(i,is)
            if (is.eq.1) egc(i)=2.d0*egc(i)
!            if (is.eq.1.and.i.lt.4) write(6,'(3f20.12)') &
!                                      vgc(i,1)
         enddo
      enddo

      deallocate(dh)
      deallocate(h)
      deallocate(grho)

      return
      end
